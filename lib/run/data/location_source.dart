import '../domain/location_sample.dart';

abstract interface class LocationSource {
  Stream<LocationSample> watch();
}
