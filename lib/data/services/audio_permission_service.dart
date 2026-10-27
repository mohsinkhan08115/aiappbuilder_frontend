import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Represents the status of audio / microphone permissions in a safe, cross-platform way.
enum AudioPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unsupported,
  unknown,
}

extension AudioPermissionStatusX on AudioPermissionStatus {
  bool get isGranted => this == AudioPermissionStatus.granted;
  bool get isDenied => this == AudioPermissionStatus.denied;
  bool get isPermanentlyDenied => this == AudioPermissionStatus.permanentlyDenied;
  bool get isRestricted => this == AudioPermissionStatus.restricted;
  bool get isUnsupported => this == AudioPermissionStatus.unsupported;
}

/// Abstract delegate to decouple permission_handler from the service for unit testing.
abstract class PermissionHandlerDelegate {
  Future<ph.PermissionStatus> checkPermission(ph.Permission permission);
  Future<ph.PermissionStatus> requestPermission(ph.Permission permission);
  Future<bool> openAppSettings();
}

/// Default implementation delegating directly to permission_handler.
class DefaultPermissionHandlerDelegate implements PermissionHandlerDelegate {
  const DefaultPermissionHandlerDelegate();

  @override
  Future<ph.PermissionStatus> checkPermission(ph.Permission permission) {
    return permission.status;
  }

  @override
  Future<ph.PermissionStatus> requestPermission(ph.Permission permission) {
    return permission.request();
  }

  @override
  Future<bool> openAppSettings() {
    return ph.openAppSettings();
  }
}

/// Service dedicated to checking and requesting microphone permissions safely.
///
/// Strictly handles permission verification and requests. Does NOT initialize audio recording,
/// STT, or TTS, and never requests permissions automatically on app startup.
class AudioPermissionService {
  final PermissionHandlerDelegate _delegate;

  AudioPermissionService({PermissionHandlerDelegate? delegate})
      : _delegate = delegate ?? const DefaultPermissionHandlerDelegate();

  /// Checks the current microphone permission status without requesting it from the user.
  Future<AudioPermissionStatus> checkPermission() async {
    try {
      final status = await _delegate.checkPermission(ph.Permission.microphone);
      return _mapStatus(status);
    } catch (e, stack) {
      debugPrint('AudioPermissionService.checkPermission error: $e\n$stack');
      return AudioPermissionStatus.unsupported;
    }
  }

  /// Requests microphone permission if not already granted.
  ///
  /// Returns the resulting [AudioPermissionStatus].
  Future<AudioPermissionStatus> requestPermission() async {
    try {
      final current = await checkPermission();
      if (current == AudioPermissionStatus.granted) {
        return AudioPermissionStatus.granted;
      }
      if (current == AudioPermissionStatus.permanentlyDenied) {
        return AudioPermissionStatus.permanentlyDenied;
      }

      final status = await _delegate.requestPermission(ph.Permission.microphone);
      return _mapStatus(status);
    } catch (e, stack) {
      debugPrint('AudioPermissionService.requestPermission error: $e\n$stack');
      return AudioPermissionStatus.unsupported;
    }
  }

  /// Opens the operating system application settings page if supported.
  /// Useful when permission is [AudioPermissionStatus.permanentlyDenied].
  Future<bool> openSettings() async {
    try {
      return await _delegate.openAppSettings();
    } catch (e, stack) {
      debugPrint('AudioPermissionService.openSettings error: $e\n$stack');
      return false;
    }
  }

  AudioPermissionStatus _mapStatus(ph.PermissionStatus status) {
    switch (status) {
      case ph.PermissionStatus.granted:
      case ph.PermissionStatus.limited:
      case ph.PermissionStatus.provisional:
        return AudioPermissionStatus.granted;
      case ph.PermissionStatus.denied:
        return AudioPermissionStatus.denied;
      case ph.PermissionStatus.permanentlyDenied:
        return AudioPermissionStatus.permanentlyDenied;
      case ph.PermissionStatus.restricted:
        return AudioPermissionStatus.restricted;
    }
  }
}
