import 'dart:async';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/models/leaf_sample.dart';
import '../constants/app_constants.dart';
import '../utils/app_date_utils.dart';

/// Structured result of a foreground GPS capture attempt.
class GpsResult {
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String? capturedAtUtc;
  final GpsStatus status;
  final String? errorMessage;

  const GpsResult({
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.capturedAtUtc,
    required this.status,
    this.errorMessage,
  });

  bool get isCaptured =>
      status == GpsStatus.captured && latitude != null && longitude != null;
}

/// Captures foreground-only GPS coordinates and accuracy for leaf samples.
class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  /// Requests foreground permission if needed and obtains a single GPS fix.
  ///
  /// Never requests background location and never inserts fallback `(0, 0)`
  /// coordinates when location is unavailable.
  Future<GpsResult> getCurrentGpsFix() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const GpsResult(
          status: GpsStatus.serviceDisabled,
          errorMessage: 'Location services are disabled on this device.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const GpsResult(
          status: GpsStatus.permissionDenied,
          errorMessage: 'Location permission was declined.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: AppConstants.gpsTimeoutSeconds),
        ),
      );

      // Guard against invalid 0,0 coordinates if platform reports none.
      if (position.latitude == 0.0 && position.longitude == 0.0) {
        return const GpsResult(
          status: GpsStatus.unavailable,
          errorMessage: 'GPS returned an uncalibrated coordinate.',
        );
      }

      return GpsResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        capturedAtUtc: AppDateUtils.nowUtcIso(),
        status: GpsStatus.captured,
      );
    } on TimeoutException {
      return const GpsResult(
        status: GpsStatus.timeout,
        errorMessage:
            'Timed out waiting for a GPS fix. You can still save the sample.',
      );
    } on PlatformException catch (e) {
      return GpsResult(
        status: GpsStatus.unavailable,
        errorMessage: e.message ?? 'Location unavailable.',
      );
    } catch (e) {
      return GpsResult(
        status: GpsStatus.unavailable,
        errorMessage: 'Location unavailable: $e',
      );
    }
  }
}
