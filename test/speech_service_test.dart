import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:aiappbuilder/data/services/audio_permission_service.dart';
import 'package:aiappbuilder/data/services/speech_service.dart';

class MockPermissionHandlerDelegate implements PermissionHandlerDelegate {
  ph.PermissionStatus status;
  int checkCount = 0;
  int requestCount = 0;

  MockPermissionHandlerDelegate({this.status = ph.PermissionStatus.granted});

  @override
  Future<ph.PermissionStatus> checkPermission(ph.Permission permission) async {
    checkCount++;
    return status;
  }

  @override
  Future<ph.PermissionStatus> requestPermission(ph.Permission permission) async {
    requestCount++;
    return status;
  }

  @override
  Future<bool> openAppSettings() async => true;
}

class MockSpeechRecognitionAdapter implements SpeechRecognitionAdapter {
  bool available;
  bool listening = false;
  bool initializeSuccess;
  bool shouldThrowOnInitialize;
  bool shouldThrowOnListen;
  bool shouldThrowOnStop;
  bool shouldThrowOnCancel;
  int initializeCount = 0;
  int listenCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  int disposeCount = 0;
  String? lastListenLocaleId;

  void Function(String status)? statusCallback;
  void Function(SpeechError error)? errorCallback;
  void Function(SpeechResult result)? resultCallback;
  void Function(double level)? soundLevelCallback;

  List<stt.LocaleName> mockLocales;
  stt.LocaleName? mockSystemLocale;

  MockSpeechRecognitionAdapter({
    this.available = true,
    this.initializeSuccess = true,
    this.shouldThrowOnInitialize = false,
    this.shouldThrowOnListen = false,
    this.shouldThrowOnStop = false,
    this.shouldThrowOnCancel = false,
    List<stt.LocaleName>? locales,
    this.mockSystemLocale,
  }) : mockLocales = locales ??
            [
              stt.LocaleName('en_US', 'English (United States)'),
              stt.LocaleName('en_GB', 'English (United Kingdom)'),
              stt.LocaleName('ur_PK', 'Urdu (Pakistan)'),
            ];

  @override
  bool get isAvailable => available;

  @override
  bool get isListening => listening;

  @override
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(SpeechError error)? onError,
  }) async {
    initializeCount++;
    if (shouldThrowOnInitialize) {
      throw Exception('Simulated adapter initialization failure');
    }
    statusCallback = onStatus;
    errorCallback = onError;
    return initializeSuccess;
  }

  @override
  Future<void> listen({
    required void Function(SpeechResult result) onResult,
    String? localeId,
    Duration? listenFor,
    Duration? pauseFor,
    bool partialResults = true,
    void Function(double soundLevel)? onSoundLevelChange,
  }) async {
    listenCount++;
    if (shouldThrowOnListen) {
      throw Exception('Simulated listen exception');
    }
    listening = true;
    lastListenLocaleId = localeId;
    resultCallback = onResult;
    soundLevelCallback = onSoundLevelChange;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    if (shouldThrowOnStop) {
      throw Exception('Simulated stop exception');
    }
    listening = false;
    statusCallback?.call('done');
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    if (shouldThrowOnCancel) {
      throw Exception('Simulated cancel exception');
    }
    listening = false;
    statusCallback?.call('notListening');
  }

  @override
  Future<List<stt.LocaleName>> getLocales() async => mockLocales;

  @override
  Future<stt.LocaleName?> getSystemLocale() async =>
      mockSystemLocale ?? (mockLocales.isNotEmpty ? mockLocales.first : null);

  @override
  Future<void> dispose() async {
    disposeCount++;
    listening = false;
  }

  // Simulation helpers for tests
  void simulateResult(String words, {bool isFinal = false, double confidence = 0.95}) {
    resultCallback?.call(
      SpeechResult(words: words, isFinal: isFinal, confidence: confidence),
    );
  }

  void simulateSoundLevel(double level) {
    soundLevelCallback?.call(level);
  }

  void simulateStatus(String status) {
    statusCallback?.call(status);
  }

  void simulateError(String msg, {bool permanent = false}) {
    errorCallback?.call(SpeechError(message: msg, permanent: permanent));
  }
}

SpeechService createTestService({
  MockSpeechRecognitionAdapter? adapter,
  ph.PermissionStatus permissionStatus = ph.PermissionStatus.granted,
  MockPermissionHandlerDelegate? permMock,
}) {
  final pMock = permMock ?? MockPermissionHandlerDelegate(status: permissionStatus);
  final permService = AudioPermissionService(delegate: pMock);
  return SpeechService(
    adapter: adapter ?? MockSpeechRecognitionAdapter(),
    permissionService: permService,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeechService - Initialization & Permission Handling', () {
    test('succeeds when permission is granted and adapter initializes', () async {
      final permMock = MockPermissionHandlerDelegate(status: ph.PermissionStatus.granted);
      final adapter = MockSpeechRecognitionAdapter(initializeSuccess: true);
      final service = createTestService(adapter: adapter, permMock: permMock);

      final ok = await service.initialize();

      expect(ok, isTrue);
      expect(service.state, SpeechServiceState.ready);
      expect(service.isAvailable, isTrue);
      expect(adapter.initializeCount, 1);
      expect(permMock.checkCount, 1);
      expect(service.supportedLocales.length, 3);
      expect(service.selectedLocaleId, 'en_US');
    });

    test('requests permission when status is initially denied and granted by user', () async {
      final permMock = MockPermissionHandlerDelegate(status: ph.PermissionStatus.denied);
      final adapter = MockSpeechRecognitionAdapter(initializeSuccess: true);
      final service = createTestService(adapter: adapter, permMock: permMock);

      // Initially denied
      final ok = await service.initialize();
      expect(ok, isFalse);
      expect(permMock.requestCount, 1);
      expect(service.state, SpeechServiceState.error);
    });

    test('fails and emits error when microphone permission is denied', () async {
      final permMock = MockPermissionHandlerDelegate(status: ph.PermissionStatus.denied);
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter, permMock: permMock);

      SpeechError? capturedError;
      service.onError = (e) => capturedError = e;

      final ok = await service.initialize();

      expect(ok, isFalse);
      expect(service.state, SpeechServiceState.error);
      expect(capturedError, isNotNull);
      expect(capturedError!.message, contains('Microphone permission was denied'));
      expect(capturedError!.permanent, isFalse);
      expect(adapter.initializeCount, 0); // Adapter must not initialize if permission denied
    });

    test('fails and marks permanent when permission is permanently denied', () async {
      final permMock = MockPermissionHandlerDelegate(status: ph.PermissionStatus.permanentlyDenied);
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter, permMock: permMock);

      SpeechError? capturedError;
      service.onError = (e) => capturedError = e;

      final ok = await service.initialize();

      expect(ok, isFalse);
      expect(service.state, SpeechServiceState.error);
      expect(capturedError!.permanent, isTrue);
      expect(capturedError!.message, contains('permanently denied'));
    });

    test('fails when adapter reports initialization failure', () async {
      final adapter = MockSpeechRecognitionAdapter(initializeSuccess: false);
      final service = createTestService(adapter: adapter);

      SpeechError? capturedError;
      service.onError = (e) => capturedError = e;

      final ok = await service.initialize();

      expect(ok, isFalse);
      expect(service.state, SpeechServiceState.error);
      expect(capturedError!.message, contains('could not be initialized'));
    });

    test('handles adapter exception gracefully without crashing', () async {
      final adapter = MockSpeechRecognitionAdapter(shouldThrowOnInitialize: true);
      final service = createTestService(adapter: adapter);

      final ok = await service.initialize();

      expect(ok, isFalse);
      expect(service.state, SpeechServiceState.error);
      expect(service.lastError!.message, contains('Simulated adapter initialization failure'));
    });

    test('does not re-initialize if already ready and available', () async {
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter);

      await service.initialize();
      final second = await service.initialize();

      expect(second, isTrue);
      expect(adapter.initializeCount, 1);
    });
  });

  group('SpeechService - Locale Discovery and Validation', () {
    test('reports English and Urdu as supported when returned by engine', () async {
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter);
      await service.initialize();

      expect(service.isEnglishSupported, isTrue);
      expect(service.isUrduSupported, isTrue);
      expect(service.isLocaleSupported('ur'), isTrue);
      expect(service.isLocaleSupported('ur_PK'), isTrue);
      expect(service.isLocaleSupported('ur-PK'), isTrue);
    });

    test('reports Pashto as unsupported when engine does not report it', () async {
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter);
      await service.initialize();

      expect(service.isPashtoSupported, isFalse);
      expect(service.isLocaleSupported('ps'), isFalse);
      expect(service.isLocaleSupported('ps_AF'), isFalse);
    });

    test('selects supported locale and updates selectedLocaleId', () async {
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter);
      await service.initialize();

      final selected = service.setLocale('ur_PK');

      expect(selected, isTrue);
      expect(service.selectedLocaleId, 'ur_PK');
    });

    test('rejects unsupported locale without changing selectedLocaleId', () async {
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter);
      await service.initialize();

      final original = service.selectedLocaleId;
      final selected = service.setLocale('ps_AF');

      expect(selected, isFalse);
      expect(service.selectedLocaleId, original);
    });
  });

  group('SpeechService - Listening and Result Processing', () {
    test('startListening triggers adapter and transitions to listening state', () async {
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter);
      await service.initialize();

      final ok = await service.startListening();

      expect(ok, isTrue);
      expect(service.state, SpeechServiceState.listening);
      expect(adapter.listenCount, 1);
    });

    test('auto-initializes if startListening is called when uninitialized', () async {
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter);

      final ok = await service.startListening();

      expect(ok, isTrue);
      expect(adapter.initializeCount, 1);
      expect(service.state, SpeechServiceState.listening);
    });

    test('ignores duplicate startListening call if already listening', () async {
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter);
      await service.initialize();

      await service.startListening();
      final duplicate = await service.startListening();

      expect(duplicate, isTrue);
      expect(adapter.listenCount, 1);
    });

    test('captures interim and final recognition results', () async {
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter);
      await service.initialize();

      final results = <SpeechResult>[];
      await service.startListening(onResultCallback: results.add);

      adapter.simulateResult('create an', isFinal: false);
      expect(service.lastRecognizedWords, 'create an');
      expect(results.length, 1);
      expect(results[0].isFinal, isFalse);

      adapter.simulateResult('create an e-commerce app', isFinal: true);
      expect(service.lastRecognizedWords, 'create an e-commerce app');
      expect(results.length, 2);
      expect(results[1].isFinal, isTrue);
    });

    test('captures live sound level changes', () async {
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter);
      await service.initialize();

      double? capturedLevel;
      await service.startListening(onSoundLevelChangeCallback: (lvl) => capturedLevel = lvl);

      adapter.simulateSoundLevel(4.5);
      expect(capturedLevel, 4.5);
    });

    test('falls back to selected locale if requested locale is unsupported', () async {
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter);
      await service.initialize();

      await service.startListening(localeId: 'ps_AF');

      expect(adapter.lastListenLocaleId, 'en_US'); // System default fallback
    });

    test('uses requested locale if it is supported', () async {
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter);
      await service.initialize();

      await service.startListening(localeId: 'ur_PK');

      expect(adapter.lastListenLocaleId, 'ur_PK');
    });
  });

  group('SpeechService - Stop, Cancel, and Error Handling', () {
    test('stopListening stops active session and transitions state', () async {
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter);
      await service.startListening();

      await service.stopListening();

      expect(adapter.stopCount, 1);
      expect(service.state, SpeechServiceState.ready);
    });

    test('cancelListening cancels active session and resets recognized words', () async {
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter);
      await service.startListening();
      adapter.simulateResult('discard me', isFinal: false);

      await service.cancelListening();

      expect(adapter.cancelCount, 1);
      expect(service.lastRecognizedWords, '');
      expect(service.state, SpeechServiceState.ready);
    });

    test('routes adapter error to onError and sets state to error', () async {
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter);
      await service.initialize();

      SpeechError? capturedError;
      service.onError = (e) => capturedError = e;

      adapter.simulateError('error_speech_timeout');

      expect(service.state, SpeechServiceState.error);
      expect(capturedError, isNotNull);
      expect(capturedError!.message, 'error_speech_timeout');
    });

    test('handles doneNoResult completion status by transitioning to ready', () async {
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter);
      await service.startListening();
      expect(service.state, SpeechServiceState.listening);

      adapter.simulateStatus('doneNoResult');
      expect(service.state, SpeechServiceState.ready);
    });

    test('handles automatic recognition termination via onStatus callback', () async {
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter);
      await service.startListening();
      expect(service.state, SpeechServiceState.listening);

      adapter.simulateStatus('notListening');
      expect(service.state, SpeechServiceState.ready);
    });

    test('dispose halts active session and prevents subsequent operations', () async {
      final adapter = MockSpeechRecognitionAdapter();
      final service = createTestService(adapter: adapter);
      await service.startListening();

      await service.dispose();

      expect(adapter.disposeCount, 1);
      expect(service.state, SpeechServiceState.disposed);

      final tryInit = await service.initialize();
      expect(tryInit, isFalse);

      final tryListen = await service.startListening();
      expect(tryListen, isFalse);
    });
  });
}
