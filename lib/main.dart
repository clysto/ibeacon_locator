import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:beacons_plugin/beacons_plugin.dart';
import 'package:ibeacon_locator/map.dart';
import 'package:ibeacon_locator/beacon.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

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

class _MyHomePageState extends State<MyHomePage> {
  final StreamController<String> _beaconEventsController =
      StreamController<String>.broadcast();
  final List<StreamSubscription<dynamic>> _sensorsSubscriptions =
      <StreamSubscription<dynamic>>[];

  // IMU 数据
  List<double>? _accelerometerValues;
  List<double>? _gyroscopeValues;
  List<double>? _magnetometerValues;

  // MQTT client
  final _client = MqttServerClient.withPort('202.38.75.252', 'ibeacon', 1883);

  bool _isConnectToMqtt = false;

  Timer? _sensorTimer;

  bool _isRunning = false;

  final Map<String, BeaconData> _beaconDataList = <String, BeaconData>{};
  BeaconMap _room = allMaps[0];

  @override
  void dispose() {
    super.dispose();
    for (final subscription in _sensorsSubscriptions) {
      subscription.cancel();
    }
    _sensorTimer?.cancel();
  }

  @override
  void initState() {
    super.initState();
    BeaconsPlugin.listenToBeacons(_beaconEventsController);
    _beaconEventsController.stream.listen(handleScanResults, onDone: () {},
        onError: (error) {
      log("Error: $error");
    });
    _sensorsSubscriptions.add(
      accelerometerEvents.listen(
        (AccelerometerEvent event) {
          _accelerometerValues = <double>[event.x, event.y, event.z];
        },
      ),
    );
    _sensorsSubscriptions.add(
      gyroscopeEvents.listen(
        (GyroscopeEvent event) {
          _gyroscopeValues = <double>[event.x, event.y, event.z];
        },
      ),
    );
    _sensorsSubscriptions.add(
      magnetometerEvents.listen(
        (MagnetometerEvent event) {
          _magnetometerValues = <double>[event.x, event.y, event.z];
        },
      ),
    );
    _sensorTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      setState(() {
        _accelerometerValues = _accelerometerValues;
        _gyroscopeValues = _gyroscopeValues;
        _magnetometerValues = _magnetometerValues;
      });
    });
  }

  ///
  /// 渲染一个 IMU 类别
  ///
  Widget _buildSensorItem(String title, List<double>? data) {
    String? x = data?.elementAt(0).toStringAsFixed(2);
    String? y = data?.elementAt(1).toStringAsFixed(2);
    String? z = data?.elementAt(2).toStringAsFixed(2);
    return Row(children: [
      Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: DecoratedBox(
              child: const Icon(Icons.sensors, size: 30, color: Colors.white),
              decoration: BoxDecoration(
                  color: Colors.blueGrey,
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
              title,
              style: const TextStyle(fontSize: 20, fontFamily: "IBM Plex Mono"),
            ),
            Text(
              "X: $x",
              style: const TextStyle(fontFamily: "IBM Plex Mono"),
            ),
            Text(
              "Y: $y",
              style: const TextStyle(fontFamily: "IBM Plex Mono"),
            ),
            Text(
              "Z: $z",
              style: const TextStyle(fontFamily: "IBM Plex Mono"),
            ),
          ],
        ),
      )
    ]);
  }

  ///
  /// 渲染 IMU 节点列表
  ///
  List<Widget> _buildSensorsTable() {
    final List<Widget> widgets = <Widget>[];
    widgets.add(_buildSensorItem("Accelerometer", _accelerometerValues));
    widgets.add(const Divider());
    widgets.add(_buildSensorItem("Gyroscope", _gyroscopeValues));
    widgets.add(const Divider());
    widgets.add(_buildSensorItem("Magnetometer", _magnetometerValues));
    widgets.add(const Divider());
    return widgets;
  }

  ///
  /// 渲染 iBeacon 节点列表
  ///
  List<Widget> _buildBeaconTable() {
    final List<Widget> widgets = <Widget>[];
    for (MapEntry<String, BeaconData> entry in _beaconDataList.entries) {
      BeaconData data = entry.value;
      String minor = entry.key;
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
                    color: Colors.lightBlue,
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
                "${data.name}(Minor: $minor)",
                style:
                    const TextStyle(fontSize: 20, fontFamily: "IBM Plex Mono"),
              ),
              Text(
                "RSSI: ${data.rssi} Distance: ${data.distance}",
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

  ///
  /// 处理扫描到的 BLE 信号
  ///
  void handleScanResults(String data) {
    if (data.isNotEmpty && _isRunning) {
      var parsed = BeaconData.fromJson(jsonDecode(data));
      // 和地图中相同 minor 的信息加入 list
      for (var beacon in _room.beacons) {
        if (beacon.minor == parsed.minor) {
          setState(() {
            _beaconDataList[parsed.minor] = parsed;
            if (_isConnectToMqtt) {
              final builder = MqttClientPayloadBuilder();
              builder.addString(data);
              _client.publishMessage(
                  "rssi", MqttQos.exactlyOnce, builder.payload!);
            }
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

  ///
  /// 是否将数据推送到服务器
  ///
  void _handleConnectStateChange(bool state) async {
    if (state) {
      if (!_isRunning) {
        return;
      }
      _isConnectToMqtt = true;
      try {
        await _client.connect();
      } on NoConnectionException catch (e) {
        // Raised by the client when connection fails.
        // print('EXAMPLE::client exception - $e');
        _isConnectToMqtt = false;
        _client.disconnect();
      } on SocketException catch (e) {
        // Raised by the socket layer
        // print('EXAMPLE::socket exception - $e');
        _client.disconnect();
        _isConnectToMqtt = false;
      }
    } else {
      _client.disconnect();
      _isConnectToMqtt = false;
    }
  }

  void _handleRoomChange(BeaconMap? room) {
    setState(() {
      _room = room!;
      _beaconDataList.clear();
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
        body: SingleChildScrollView(
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text("是否推送到服务器",
                        style: TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.bold)),
                    Switch(
                      value: _isConnectToMqtt,
                      onChanged: _handleConnectStateChange,
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.only(top: 16, bottom: 0),
                  child: Column(
                    children: _isRunning ? _buildSensorsTable() : <Widget>[],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.only(top: 0, bottom: 16),
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
