import 'package:latlong2/latlong.dart';

class Client {
  final String id;
  final String name;
  final String? contactNumber;
  final String? address;
  final String? barangay;
  final double? latitude;
  final double? longitude;
  final String? meterNumber;
  final DateTime connectionDate;
  final String status;
  final List<LatLng>? boundary;

  Client({
    required this.id,
    required this.name,
    this.contactNumber,
    this.address,
    this.barangay,
    this.latitude,
    this.longitude,
    this.meterNumber,
    required this.connectionDate,
    required this.status,
    this.boundary,
  });

  factory Client.fromMap(Map<String, dynamic> map) => Client(
        id: map['id'] as String,
        name: map['name'] as String,
        contactNumber: map['contact_number'] as String?,
        address: map['address'] as String?,
        barangay: map['barangay'] as String?,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        meterNumber: map['meter_number'] as String?,
        connectionDate: DateTime.parse(map['connection_date'] as String),
        status: map['status'] as String,
        boundary: (map['boundary'] as List?)
            ?.map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
            .toList(),
      );

  Map<String, dynamic> toInsertMap() => {
        'name': name,
        'contact_number': contactNumber,
        'address': address,
        'barangay': barangay,
        'latitude': latitude,
        'longitude': longitude,
        'meter_number': meterNumber,
        'connection_date': connectionDate.toIso8601String().split('T').first,
        'status': status,
      };

  static List<List<double>> encodeBoundary(List<LatLng> points) =>
      points.map((p) => [p.latitude, p.longitude]).toList();

  bool get hasLocation => latitude != null && longitude != null;
  bool get hasBoundary => boundary != null && boundary!.length >= 3;
}
