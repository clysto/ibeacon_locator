class Beacon {
  String uuid;
  String major;
  String minor;

  Beacon(this.uuid, this.major, this.minor);
}

class BeaconMap {
  String name;
  List<Beacon> beacons = <Beacon>[];

  BeaconMap(this.name);

  void addBeacon(Beacon beacon) {
    beacons.add(beacon);
  }

  @override
  String toString() {
    return name;
  }
}

List<BeaconMap> _buildAllMaps() {
  var room804 = BeaconMap("信智楼B804房间");
  room804.addBeacon(
      Beacon("01122334-4556-6778-899A-ABBCCDDEEFF0", "10006", "19216"));
  room804.addBeacon(
      Beacon("01122334-4556-6778-899A-ABBCCDDEEFF0", "10006", "19260"));
  room804.addBeacon(
      Beacon("01122334-4556-6778-899A-ABBCCDDEEFF0", "10006", "18739"));
  return <BeaconMap>[room804];
}

var allMaps = _buildAllMaps();

BeaconMap? getMap(String name) {
  for (var map in allMaps) {
    if (map.name == name) {
      return map;
    }
  }
  return null;
}
