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
