import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:aiappbuilder/data/services/audio_permission_service.dart';

class MockPermissionHandlerDelegate implements PermissionHandlerDelegate {
  ph.PermissionStatus checkStatusResult;
  ph.PermissionStatus? requestStatusResult;
  bool openSettingsResult;
  bool shouldThrowOnCheck;
  bool shouldThrowOnRequest;
  bool shouldThrowOnOpenSettings;
  int checkPermissionCallCount = 0;
  int requestPermissionCallCount = 0;
  int openSettingsCallCount = 0;

  MockPermissionHandlerDelegate({
    this.checkStatusResult = ph.PermissionStatus.denied,
    this.requestStatusResult,
    this.openSettingsResult = true,
    this.shouldThrowOnCheck = false,
    this.shouldThrowOnRequest = false,
    this.shouldThrowOnOpenSettings = false,
  });

  @override
  Future<ph.PermissionStatus> checkPermission(ph.Permission permission) async {
    checkPermissionCallCount++;
    if (shouldThrowOnCheck) {
      throw Exception('Simulated platform error during checkPermission');
    }
    return checkStatusResult;
  }

  @override
  Future<ph.PermissionStatus> requestPermission(ph.Permission permission) async {
    requestPermissionCallCount++;
    if (shouldThrowOnRequest) {
      throw Exception('Simulated platform error during requestPermission');
    }
    return requestStatusResult ?? checkStatusResult;
  }

  @override
  Future<bool> openAppSettings() async {
    openSettingsCallCount++;
    if (shouldThrowOnOpenSettings) {
      throw Exception('Simulated platform error during openAppSettings');
    }
    return openSettingsResult;
  }
}

void main() {
  group('AudioPermissionService - Check Permission', () {
    test('returns AudioPermissionStatus.granted when permission is granted', () async {
      final mock = MockPermissionHandlerDelegate(checkStatusResult: ph.PermissionStatus.granted);
      final service = AudioPermissionService(delegate: mock);

      final status = await service.checkPermission();

      expect(status, AudioPermissionStatus.granted);
      expect(status.isGranted, isTrue);
      expect(mock.checkPermissionCallCount, 1);
    });

    test('returns AudioPermissionStatus.denied when permission is denied', () async {
      final mock = MockPermissionHandlerDelegate(checkStatusResult: ph.PermissionStatus.denied);
      final service = AudioPermissionService(delegate: mock);

      final status = await service.checkPermission();

      expect(status, AudioPermissionStatus.denied);
      expect(status.isDenied, isTrue);
      expect(mock.checkPermissionCallCount, 1);
    });

    test('returns AudioPermissionStatus.permanentlyDenied when permanently denied', () async {
      final mock = MockPermissionHandlerDelegate(
        checkStatusResult: ph.PermissionStatus.permanentlyDenied,
      );
      final service = AudioPermissionService(delegate: mock);

      final status = await service.checkPermission();

      expect(status, AudioPermissionStatus.permanentlyDenied);
      expect(status.isPermanentlyDenied, isTrue);
      expect(mock.checkPermissionCallCount, 1);
    });

    test('returns AudioPermissionStatus.restricted when restricted (e.g. parental controls)', () async {
      final mock = MockPermissionHandlerDelegate(
        checkStatusResult: ph.PermissionStatus.restricted,
      );
      final service = AudioPermissionService(delegate: mock);

      final status = await service.checkPermission();

      expect(status, AudioPermissionStatus.restricted);
      expect(status.isRestricted, isTrue);
      expect(mock.checkPermissionCallCount, 1);
    });

    test('returns AudioPermissionStatus.unsupported when platform error occurs', () async {
      final mock = MockPermissionHandlerDelegate(shouldThrowOnCheck: true);
      final service = AudioPermissionService(delegate: mock);

      final status = await service.checkPermission();

      expect(status, AudioPermissionStatus.unsupported);
      expect(status.isUnsupported, isTrue);
      expect(mock.checkPermissionCallCount, 1);
    });
  });

  group('AudioPermissionService - Request Permission', () {
    test('immediately returns granted without requesting if already granted', () async {
      final mock = MockPermissionHandlerDelegate(
        checkStatusResult: ph.PermissionStatus.granted,
        requestStatusResult: ph.PermissionStatus.granted,
      );
      final service = AudioPermissionService(delegate: mock);

      final status = await service.requestPermission();

      expect(status, AudioPermissionStatus.granted);
      expect(mock.checkPermissionCallCount, 1);
      expect(mock.requestPermissionCallCount, 0); // Did not pop OS prompt
    });

    test('immediately returns permanentlyDenied without requesting if permanently denied', () async {
      final mock = MockPermissionHandlerDelegate(
        checkStatusResult: ph.PermissionStatus.permanentlyDenied,
        requestStatusResult: ph.PermissionStatus.permanentlyDenied,
      );
      final service = AudioPermissionService(delegate: mock);

      final status = await service.requestPermission();

      expect(status, AudioPermissionStatus.permanentlyDenied);
      expect(mock.checkPermissionCallCount, 1);
      expect(mock.requestPermissionCallCount, 0); // Cannot pop OS prompt when permanently denied
    });

    test('requests permission and returns granted when user grants it', () async {
      final mock = MockPermissionHandlerDelegate(
        checkStatusResult: ph.PermissionStatus.denied,
        requestStatusResult: ph.PermissionStatus.granted,
      );
      final service = AudioPermissionService(delegate: mock);

      final status = await service.requestPermission();

      expect(status, AudioPermissionStatus.granted);
      expect(mock.checkPermissionCallCount, 1);
      expect(mock.requestPermissionCallCount, 1);
    });

    test('requests permission and returns denied when user denies it', () async {
      final mock = MockPermissionHandlerDelegate(
        checkStatusResult: ph.PermissionStatus.denied,
        requestStatusResult: ph.PermissionStatus.denied,
      );
      final service = AudioPermissionService(delegate: mock);

      final status = await service.requestPermission();

      expect(status, AudioPermissionStatus.denied);
      expect(mock.checkPermissionCallCount, 1);
      expect(mock.requestPermissionCallCount, 1);
    });

    test('requests permission and returns permanentlyDenied when user selects "Never ask again"', () async {
      final mock = MockPermissionHandlerDelegate(
        checkStatusResult: ph.PermissionStatus.denied,
        requestStatusResult: ph.PermissionStatus.permanentlyDenied,
      );
      final service = AudioPermissionService(delegate: mock);

      final status = await service.requestPermission();

      expect(status, AudioPermissionStatus.permanentlyDenied);
      expect(mock.checkPermissionCallCount, 1);
      expect(mock.requestPermissionCallCount, 1);
    });

    test('returns unsupported when platform error occurs during request', () async {
      final mock = MockPermissionHandlerDelegate(
        checkStatusResult: ph.PermissionStatus.denied,
        shouldThrowOnRequest: true,
      );
      final service = AudioPermissionService(delegate: mock);

      final status = await service.requestPermission();

      expect(status, AudioPermissionStatus.unsupported);
      expect(mock.checkPermissionCallCount, 1);
      expect(mock.requestPermissionCallCount, 1);
    });
  });

  group('AudioPermissionService - Open App Settings', () {
    test('returns true when delegate successfully opens settings', () async {
      final mock = MockPermissionHandlerDelegate(openSettingsResult: true);
      final service = AudioPermissionService(delegate: mock);

      final result = await service.openSettings();

      expect(result, isTrue);
      expect(mock.openSettingsCallCount, 1);
    });

    test('returns false when delegate fails to open settings', () async {
      final mock = MockPermissionHandlerDelegate(openSettingsResult: false);
      final service = AudioPermissionService(delegate: mock);

      final result = await service.openSettings();

      expect(result, isFalse);
      expect(mock.openSettingsCallCount, 1);
    });

    test('returns false without crashing when delegate throws error on openSettings', () async {
      final mock = MockPermissionHandlerDelegate(shouldThrowOnOpenSettings: true);
      final service = AudioPermissionService(delegate: mock);

      final result = await service.openSettings();

      expect(result, isFalse);
      expect(mock.openSettingsCallCount, 1);
    });
  });
}
