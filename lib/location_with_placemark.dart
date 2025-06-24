import 'package:geocoding/geocoding.dart';
import 'package:geocoding_platform_interface/src/models/location.dart';

class LocationWithPlacemark extends Location {
  final Placemark placemark;

  const LocationWithPlacemark({required super.latitude, required super.longitude, required super.timestamp, required this.placemark});
}