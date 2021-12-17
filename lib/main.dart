import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:beacons_plugin/beacons_plugin.dart';
import 'package:ibeacon_locator/map.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iBeacon Locator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'iBeacon Locator'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class BeaconData {
  String name;
  String uuid;
  String major;
  String minor;
  String rssi;
  String distance;
  String proximity;

  BeaconData(this.name, this.uuid, this.major, this.minor, this.rssi,
      this.distance, this.proximity);

  BeaconData.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        uuid = json['uuid'],
        major = json['major'],
        minor = json['minor'],
        rssi = json['rssi'],
        distance = json['distance'],
        proximity = json['proximity'];
}

class _MyHomePageState extends State<MyHomePage> {
  final StreamController<String> _beaconEventsController =
      StreamController<String>.broadcast();

  bool _isRunning = false;
  final Map<String, BeaconData> _beaconDataList = <String, BeaconData>{};
  BeaconMap _room = allMaps[0];

  @override
  void initState() {
    super.initState();
    BeaconsPlugin.listenToBeacons(_beaconEventsController);
    _beaconEventsController.stream.listen(handleScanResults, onDone: () {},
        onError: (error) {
      log("Error: $error");
    });
  }

  List<Widget> _buildBeaconTable() {
    final List<Widget> widgets = <Widget>[];
    for (BeaconData data in _beaconDataList.values) {
      widgets.add(Row(children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: DecoratedBox(
                child:
                    const Icon(Icons.bluetooth, size: 30, color: Colors.white),
                decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                data.name,
                style:
                    const TextStyle(fontSize: 20, fontFamily: "IBM Plex Mono"),
              ),
              Text(
                "RSSI: ${data.rssi}",
                style: const TextStyle(fontFamily: "IBM Plex Mono"),
              ),
              Text(
                data.uuid,
                overflow: TextOverflow.fade,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                    color: Colors.grey, fontFamily: "IBM Plex Mono"),
              ),
            ],
          ),
        )
      ]));
      widgets.add(const Divider());
    }
    return widgets;
  }

  void handleScanResults(String data) {
    if (data.isNotEmpty && _isRunning) {
      var parsed = BeaconData.fromJson(jsonDecode(data));
      // 和地图中相同 minor 的信息加入 list
      for (var beacon in _room.beacons) {
        if (beacon.minor == parsed.minor) {
          setState(() {
            _beaconDataList[parsed.minor] = parsed;
          });
        }
      }
    }
  }

  void _startScan() async {
    // 开始扫描

    for (var beacon in _room.beacons) {
      await BeaconsPlugin.addRegion("EW80ECCACD", beacon.uuid);
    }

    await BeaconsPlugin.startMonitoring();

    setState(() {
      _isRunning = true;
    });
  }

  void _stopScan() async {
    // 停止扫描
    await BeaconsPlugin.stopMonitoring();
    await BeaconsPlugin.clearRegions();
    setState(() {
      _isRunning = false;
      _beaconDataList.clear();
    });
  }

  void _handleRoomChange(BeaconMap? room) {
    setState(() {
      _room = room!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        bottomNavigationBar: BottomAppBar(
          color: Colors.transparent,
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                ),
                onPressed: _isRunning ? _stopScan : _startScan,
                child: Text(_isRunning ? "停止扫描" : "开始扫描"),
              )),
          elevation: 0,
        ),
        body: Container(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              children: <Widget>[
                DropdownButton<BeaconMap>(
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_downward),
                  onChanged: _handleRoomChange,
                  value: _room,
                  items:
                      allMaps.map<DropdownMenuItem<BeaconMap>>((BeaconMap map) {
                    return DropdownMenuItem<BeaconMap>(
                      value: map,
                      child: Text(map.name),
                    );
                  }).toList(),
                ),
                Container(
                  padding: const EdgeInsets.only(top: 16, bottom: 16),
                  child: Column(
                    children: _buildBeaconTable(),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
