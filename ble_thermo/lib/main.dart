import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text("Thermo"),
        ),
        body: Center(
          child: ThremoListView(),
        ),
      ),
    );
  }
}

class ThremoListView extends StatefulWidget {
  @override
  _ThremoListViewState createState() => _ThremoListViewState();
}

class _ThremoListViewState extends State<ThremoListView> {
  BleManager _bleManager = BleManager();
  StreamSubscription<ScanResult> _scanSubscription;
   PermissionStatus _locationPermissionStatus = PermissionStatus.unknown;
  int _rssi = 0;
  double _humid = 0;
  double _temp = 0;
  int _seq = 0;
  int _tx = 0;

  Queue _average_rssi = Queue();

  _ThremoListViewState() {
    _bleManager.createClient(
        restoreStateIdentifier: "ble-thermo-restore-state-identifier",
        restoreStateAction: (peripherals) {
          peripherals?.forEach((peripheral) {
            print("Restored peripheral: ${peripheral.name}");
          });
        });

    _startScan();
  }

  @override
  void dispose() {
    _bleManager.destroyClient();
    super.dispose();
  }

  Future<void> _startScan() async {
    BluetoothState currentState = BluetoothState.UNKNOWN;

    if (Platform.isAndroid) {
      var permissionStatus = await PermissionHandler()
          .requestPermissions([PermissionGroup.location]);

      _locationPermissionStatus = permissionStatus[PermissionGroup.location];

      if (_locationPermissionStatus != PermissionStatus.granted) {
        return Future.error(Exception("Location permission not granted"));
      }
    }

    do {
      currentState = await _bleManager.bluetoothState();
      print("current State: $currentState");
      sleep(Duration(milliseconds: 1000));
    } while (currentState != BluetoothState.POWERED_ON);

    _scanSubscription =
        _bleManager.startPeripheralScan(allowDuplicates:true).listen((ScanResult scanResult) {
      if (scanResult.peripheral.name != 'BLE M5Stack Thermo') {
        return;
      }

      print(
          "manufacturor ${scanResult.advertisementData.manufacturerData}, service uuid=${scanResult.advertisementData.serviceData}");
      setState(() {
        var data = scanResult.advertisementData.manufacturerData;
        _rssi = scanResult.rssi;
        _average_rssi.addFirst(scanResult.rssi);
        _seq = (data[3] + (data[4] << 8) + (data[5] << 16) + (data[6] << 24));
        _temp = (data[7] + (data[8] << 8)) / 100.0;
        _humid = (data[9] + (data[10] << 8)) / 100.0;
        _tx = scanResult.advertisementData.txPowerLevel;
        if (_average_rssi.length > 5) {
          int remove_count = _average_rssi.length - 5;
          for (int i = 0; i < remove_count; i++) {
            _average_rssi.removeLast();
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: GridView.count(crossAxisCount: 2, children: [
      Temp(_temp),
      Humid(_humid),
      LastUpdate(DateTime.now()),
      DataCard("Tx", _tx.toString() + "db"),
      RSSI(_rssi),
      _average_rssi.length == 0
          ? RSSIAve(0)
          : RSSIAve((_average_rssi.fold(
                      0, (previous, current) => previous + current) /
                  _average_rssi.length)
              .round()),
                    Seq(_seq),

    ]));
  }
}

class RSSI extends StatelessWidget {
  String _dbstr = "--";
  Color _bgColor = Colors.white;

  RSSI(int db) {
    if (db < 0) {
      _dbstr = db.toString();
    }

    if (db >= 0) {
      return;
    } else if (db > -30) {
      _bgColor = Colors.green;
    } else if (db > -70) {
      _bgColor = Colors.yellow;
    } else {
      _bgColor = Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Card(
        color: _bgColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('RSSI', style: Theme.of(context).textTheme.headline5),
              Text("${_dbstr} db",
                  style: Theme.of(context).textTheme.headline3),
            ],
          ),
        ),
      ),
    );
  }
}

class RSSIAve extends StatelessWidget {
  String _dbstr = "--";
  Color _bgColor = Colors.white;

  RSSIAve(int db) {
    if (db < 0) {
      _dbstr = db.toString();
    }

    if (db >= 0) {
      return;
    } else if (db > -30) {
      _bgColor = Colors.green;
    } else if (db > -70) {
      _bgColor = Colors.yellow;
    } else {
      _bgColor = Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Card(
        color: _bgColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('RSSI Average',
                  style: Theme.of(context).textTheme.headline5),
              Text("${_dbstr} db",
                  style: Theme.of(context).textTheme.headline3),
            ],
          ),
        ),
      ),
    );
  }
}

class Temp extends StatelessWidget {
  String _temp = "---.-";

  Temp(double temp) {
    if (temp >= -245) {
      _temp = temp.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Card(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('気温', style: Theme.of(context).textTheme.headline5),
              Text("${_temp} ℃", style: Theme.of(context).textTheme.headline3),
            ],
          ),
        ),
      ),
    );
  }
}

class Seq extends StatelessWidget {
  String _seq = "-------";

  Seq(int seq) {
    if (seq > 0) {
      _seq = seq.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Card(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('送信No.', style: Theme.of(context).textTheme.headline5),
              Text("${_seq} ", style: Theme.of(context).textTheme.headline3),
            ],
          ),
        ),
      ),
    );
  }
}

class Humid extends StatelessWidget {
  String _humid = "--";

  Humid(double humid) {
    if (humid > 0) {
      _humid = humid.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Card(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('湿度', style: Theme.of(context).textTheme.headline5),
              Text("${_humid} %", style: Theme.of(context).textTheme.headline3),
            ],
          ),
        ),
      ),
    );
  }
}

class LastUpdate extends StatelessWidget {
  String _time = "--:--:--.---";
  DateFormat format = DateFormat('HH:mm:ss.S');
  LastUpdate(DateTime lastUpdate) {
    _time = format.format(lastUpdate);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Card(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('最終更新時刻', style: Theme.of(context).textTheme.headline5),
              Text("${_time}", style: Theme.of(context).textTheme.headline5),
            ],
          ),
        ),
      ),
    );
  }
}

class DataCard extends StatelessWidget {
  String _label = "";
  String _data = "";

  DataCard(String label, String data ) : _label=label, _data = data;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Card(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_label, style: Theme.of(context).textTheme.headline5),
              Text(_data, style: Theme.of(context).textTheme.headline3),
            ],
          ),
        ),
      ),
    );
  }
}
