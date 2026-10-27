import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiappbuilder/data/services/tts_service.dart';

class MockTtsAdapter implements TtsAdapter {
  bool awaitSpeakCompletionValue = false;
  int speakCount = 0;
  int stopCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  int setLanguageCount = 0;
  int setVoiceCount = 0;
  int clearVoiceCount = 0;
  int setSpeechRateCount = 0;
  int setVolumeCount = 0;
  int setPitchCount = 0;

  String? lastSpokenText;
  String? lastLanguage;
  Map<String, String>? lastVoice;
  double? lastSpeechRate;
  double? lastVolume;
  double? lastPitch;

  bool shouldThrowOnSpeak = false;
  bool shouldThrowOnStop = false;
  bool shouldThrowOnPause = false;
  bool shouldThrowOnResume = false;
  bool shouldThrowOnSetLanguage = false;
  bool shouldThrowOnGetLanguages = false;

  VoidCallback? startHandler;
  VoidCallback? completionHandler;
  VoidCallback? pauseHandler;
  VoidCallback? continueHandler;
  VoidCallback? cancelHandler;
  void Function(String text, int start, int end, String word)? progressHandler;
  void Function(dynamic message)? errorHandler;

  List<dynamic> mockLanguages;
  List<dynamic> mockVoices;

  MockTtsAdapter({
    List<dynamic>? languages,
    List<dynamic>? voices,
  })  : mockLanguages = languages ??
            [
              'en-US',
              'en-GB',
              'ur-PK',
            ],
        mockVoices = voices ??
            [
              {
                'name': 'en-us-x-sfg#female_1-local',
                'locale': 'en-US',
                'gender': 'female',
                'identifier': 'com.apple.voice.en-US.Samantha',
              },
              {
                'name': 'en-us-x-sfg#male_1-local',
                'locale': 'en-US',
                'gender': 'male',
                'identifier': 'com.apple.voice.en-US.Alex',
              },
              {
                'name': 'ur-pk-x-urm-local',
                'locale': 'ur-PK',
                // Explicitly no gender metadata
              },
              {
                'name': 'Karen',
                'locale': 'en-AU',
                // Name implies gender colloquially, but metadata is missing -> MUST be unknown
              },
            ];

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async {
    awaitSpeakCompletionValue = awaitCompletion;
    return true;
  }

  @override
  Future<dynamic> speak(String text) async {
    speakCount++;
    lastSpokenText = text;
    if (shouldThrowOnSpeak) {
      throw Exception('Simulated speak failure');
    }
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    stopCount++;
    if (shouldThrowOnStop) {
      throw Exception('Simulated stop failure');
    }
    return 1;
  }

  @override
  Future<dynamic> pause() async {
    pauseCount++;
    if (shouldThrowOnPause) {
      throw Exception('Simulated pause failure');
    }
    return 1;
  }

  @override
  Future<dynamic> resume() async {
    resumeCount++;
    if (shouldThrowOnResume) {
      throw Exception('Simulated resume failure');
    }
    return 1;
  }

  @override
  Future<dynamic> setLanguage(String language) async {
    setLanguageCount++;
    lastLanguage = language;
    if (shouldThrowOnSetLanguage) {
      throw Exception('Simulated setLanguage failure');
    }
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    setSpeechRateCount++;
    lastSpeechRate = rate;
    return 1;
  }

  @override
  Future<dynamic> setVolume(double volume) async {
    setVolumeCount++;
    lastVolume = volume;
    return 1;
  }

  @override
  Future<dynamic> setPitch(double pitch) async {
    setPitchCount++;
    lastPitch = pitch;
    return 1;
  }

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async {
    setVoiceCount++;
    lastVoice = voice;
    return 1;
  }

  @override
  Future<dynamic> clearVoice() async {
    clearVoiceCount++;
    lastVoice = null;
    return 1;
  }

  @override
  Future<dynamic> getLanguages() async {
    if (shouldThrowOnGetLanguages) {
      throw Exception('Simulated getLanguages failure');
    }
    return mockLanguages;
  }

  @override
  Future<dynamic> getVoices() async => mockVoices;

  @override
  Future<dynamic> isLanguageAvailable(String language) async {
    return mockLanguages.contains(language);
  }

  @override
  void setStartHandler(VoidCallback callback) => startHandler = callback;

  @override
  void setCompletionHandler(VoidCallback callback) =>
      completionHandler = callback;

  @override
  void setPauseHandler(VoidCallback callback) => pauseHandler = callback;

  @override
  void setContinueHandler(VoidCallback callback) =>
      continueHandler = callback;

  @override
  void setCancelHandler(VoidCallback callback) => cancelHandler = callback;

  @override
  void setProgressHandler(
          void Function(String text, int start, int end, String word)
              callback) =>
      progressHandler = callback;

  @override
  void setErrorHandler(void Function(dynamic message) handler) =>
      errorHandler = handler;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTtsAdapter adapter;
  late TtsService service;

  setUp(() {
    adapter = MockTtsAdapter();
    service = TtsService(adapter: adapter);
  });

  tearDown(() async {
    await service.dispose();
  });

  group('TtsService - Initialization & Discovery', () {
    test('initializes successfully, discovers languages and voices, and sets ready state', () async {
      expect(service.state, equals(TtsServiceState.uninitialized));

      final success = await service.initialize();

      expect(success, isTrue);
      expect(service.state, equals(TtsServiceState.ready));
      expect(service.isReady, isTrue);
      expect(adapter.awaitSpeakCompletionValue, isTrue);
      expect(service.supportedLanguages, containsAll(['en-US', 'en-GB', 'ur-PK']));
      expect(service.availableVoices.length, equals(4));
      expect(service.currentLanguage, equals('en-US'));
    });

    test('handles initialization failure gracefully when adapter throws', () async {
      adapter.shouldThrowOnGetLanguages = true;

      final success = await service.initialize();

      // getLanguages exception is caught gracefully inside _discoverLanguages
      expect(success, isTrue);
      expect(service.supportedLanguages, isEmpty);
    });

    test('does not re-run full initialization if already ready', () async {
      await service.initialize();
      expect(service.state, equals(TtsServiceState.ready));

      final initialSetLangCount = adapter.setLanguageCount;
      final success = await service.initialize();

      expect(success, isTrue);
      expect(adapter.setLanguageCount, equals(initialSetLangCount));
    });
  });

  group('TtsService - Speaking & Concurrency Guardrails', () {
    test('speaks text and updates state to speaking', () async {
      final success = await service.speak('Hello world');

      expect(success, isTrue);
      expect(service.state, equals(TtsServiceState.speaking));
      expect(service.isSpeaking, isTrue);
      expect(adapter.speakCount, equals(1));
      expect(adapter.lastSpokenText, equals('Hello world'));
    });

    test('rejects empty or whitespace-only text with domain error', () async {
      TtsError? capturedError;
      service.onError = (e) => capturedError = e;

      final successEmpty = await service.speak('');
      expect(successEmpty, isFalse);
      expect(capturedError?.code, equals('empty_text'));

      final successWhitespace = await service.speak('   \t\n  ');
      expect(successWhitespace, isFalse);
      expect(capturedError?.code, equals('empty_text'));
      expect(adapter.speakCount, equals(0));
    });

    test('auto-initializes if speak is invoked prior to initialize', () async {
      expect(service.state, equals(TtsServiceState.uninitialized));

      final success = await service.speak('Auto initialize test');

      expect(success, isTrue);
      expect(adapter.speakCount, equals(1));
      expect(service.supportedLanguages, isNotEmpty);
    });

    test('prevents conflicting session when already speaking without interrupt flag', () async {
      await service.speak('First message');
      expect(service.state, equals(TtsServiceState.speaking));

      TtsError? error;
      service.onError = (e) => error = e;

      final successSecond = await service.speak('Second message', interrupt: false);

      expect(successSecond, isFalse);
      expect(error?.code, equals('already_speaking'));
      expect(adapter.speakCount, equals(1)); // Did not speak second message
      expect(adapter.lastSpokenText, equals('First message'));
    });

    test('interrupts ongoing speech and speaks new text when interrupt is true', () async {
      await service.speak('First message');
      expect(service.state, equals(TtsServiceState.speaking));

      final successSecond = await service.speak('Second message', interrupt: true);

      expect(successSecond, isTrue);
      expect(adapter.stopCount, equals(1));
      expect(adapter.speakCount, equals(2));
      expect(adapter.lastSpokenText, equals('Second message'));
      expect(service.state, equals(TtsServiceState.speaking));
    });

    test('handles adapter exception during speak without crashing', () async {
      adapter.shouldThrowOnSpeak = true;
      TtsError? error;
      service.onError = (e) => error = e;

      final success = await service.speak('Will fail');

      expect(success, isFalse);
      expect(service.state, equals(TtsServiceState.error));
      expect(error?.code, equals('speak_failed'));
    });
  });

  group('TtsService - State Transitions and Adapter Callbacks', () {
    test('transitions to ready when adapter fires completion handler', () async {
      await service.speak('Speaking utterance');
      expect(service.state, equals(TtsServiceState.speaking));

      bool completionCalled = false;
      service.onCompletion = () => completionCalled = true;

      adapter.completionHandler?.call();

      expect(service.state, equals(TtsServiceState.ready));
      expect(service.isSpeaking, isFalse);
      expect(completionCalled, isTrue);
    });

    test('transitions to ready when adapter fires cancel handler', () async {
      await service.speak('Speaking utterance');
      expect(service.state, equals(TtsServiceState.speaking));

      bool cancelCalled = false;
      service.onCancel = () => cancelCalled = true;

      adapter.cancelHandler?.call();

      expect(service.state, equals(TtsServiceState.ready));
      expect(cancelCalled, isTrue);
    });

    test('transitions to paused when adapter fires pause handler', () async {
      await service.speak('Speaking utterance');
      expect(service.state, equals(TtsServiceState.speaking));

      bool pauseCalled = false;
      service.onPause = () => pauseCalled = true;

      adapter.pauseHandler?.call();

      expect(service.state, equals(TtsServiceState.paused));
      expect(service.isPaused, isTrue);
      expect(pauseCalled, isTrue);
    });

    test('transitions to speaking when adapter fires continue handler', () async {
      await service.speak('Speaking utterance');
      adapter.pauseHandler?.call();
      expect(service.state, equals(TtsServiceState.paused));

      bool continueCalled = false;
      service.onContinue = () => continueCalled = true;

      adapter.continueHandler?.call();

      expect(service.state, equals(TtsServiceState.speaking));
      expect(continueCalled, isTrue);
    });

    test('routes platform error to onError and transitions to error state', () async {
      await service.initialize();

      TtsError? capturedError;
      service.onError = (e) => capturedError = e;

      adapter.errorHandler?.call('Synthesizer failure code 12');

      expect(service.state, equals(TtsServiceState.error));
      expect(capturedError?.code, equals('platform_error'));
      expect(capturedError?.message, contains('Synthesizer failure code 12'));
    });

    test('streams progress events to onProgress and progressStream', () async {
      await service.initialize();

      final emittedProgress = <TtsProgress>[];
      service.progressStream.listen(emittedProgress.add);

      TtsProgress? callbackProgress;
      service.onProgress = (p) => callbackProgress = p;

      adapter.progressHandler?.call('Hello world', 0, 5, 'Hello');
      await pumpEventQueue();

      expect(callbackProgress?.word, equals('Hello'));
      expect(callbackProgress?.start, equals(0));
      expect(callbackProgress?.end, equals(5));
      expect(emittedProgress.length, equals(1));
      expect(emittedProgress.first.word, equals('Hello'));
    });
  });

  group('TtsService - Stop, Pause, and Resume', () {
    test('stop transitions state to ready and calls adapter stop', () async {
      await service.speak('Testing stop');
      expect(service.state, equals(TtsServiceState.speaking));

      await service.stop();

      expect(adapter.stopCount, equals(1));
      expect(service.state, equals(TtsServiceState.ready));
    });

    test('pause pauses speech when actively speaking', () async {
      await service.speak('Testing pause');
      expect(service.state, equals(TtsServiceState.speaking));

      final success = await service.pause();

      expect(success, isTrue);
      expect(adapter.pauseCount, equals(1));
      expect(service.state, equals(TtsServiceState.paused));
    });

    test('pause returns false when not speaking', () async {
      await service.initialize();
      expect(service.state, equals(TtsServiceState.ready));

      final success = await service.pause();

      expect(success, isFalse);
      expect(adapter.pauseCount, equals(0));
    });

    test('resume resumes speech when paused', () async {
      await service.speak('Testing resume');
      await service.pause();
      expect(service.state, equals(TtsServiceState.paused));

      final success = await service.resume();

      expect(success, isTrue);
      expect(adapter.resumeCount, equals(1));
      expect(service.state, equals(TtsServiceState.speaking));
    });

    test('resume returns false when not paused', () async {
      await service.initialize();
      expect(service.state, equals(TtsServiceState.ready));

      final success = await service.resume();

      expect(success, isFalse);
      expect(adapter.resumeCount, equals(0));
    });
  });

  group('TtsService - Languages: English, Urdu, and Pashto Verification', () {
    test('reports English and Urdu as supported when discovered from engine', () async {
      await service.initialize();

      expect(service.isLanguageSupported('en-US'), isTrue);
      expect(service.isLanguageSupported('en'), isTrue);
      expect(service.isLanguageSupported('ur-PK'), isTrue);
      expect(service.isLanguageSupported('ur'), isTrue);
    });

    test('strictly reports Pashto as unsupported when engine does not list it', () async {
      await service.initialize();

      expect(service.isLanguageSupported('ps-AF'), isFalse);
      expect(service.isLanguageSupported('ps'), isFalse);
    });

    test('successfully sets supported language (Urdu)', () async {
      await service.initialize();

      final success = await service.setLanguage('ur-PK');

      expect(success, isTrue);
      expect(service.currentLanguage, equals('ur-PK'));
      expect(adapter.lastLanguage, equals('ur-PK'));
    });

    test('rejects unsupported language (Pashto) without falsely claiming it was set', () async {
      await service.initialize();
      final initialLang = service.currentLanguage;

      TtsError? capturedError;
      service.onError = (e) => capturedError = e;

      final success = await service.setLanguage('ps-AF');

      expect(success, isFalse);
      expect(service.currentLanguage, equals(initialLang)); // Kept original
      expect(capturedError?.code, equals('unsupported_language'));
      expect(capturedError?.message, contains('ps-AF'));
    });

    test('falls back safely to default language when fallbackToDefault is requested for unsupported language', () async {
      await service.initialize();
      expect(service.currentLanguage, equals('en-US'));

      final success = await service.setLanguage('ps-AF', fallbackToDefault: true);

      expect(success, isFalse); // Did not set requested ps-AF
      expect(service.currentLanguage, equals('en-US')); // Retained active fallback
    });
  });

  group('TtsService - Voice Selection & Gender Metadata Integrity', () {
    test('filters voices by explicit platform gender metadata', () async {
      await service.initialize();

      final femaleVoices = service.getVoicesForGender(TtsVoiceGender.female);
      final maleVoices = service.getVoicesForGender(TtsVoiceGender.male);
      final unknownVoices = service.getVoicesForGender(TtsVoiceGender.unknown);

      expect(femaleVoices.length, equals(1));
      expect(femaleVoices.first.name, contains('female_1'));

      expect(maleVoices.length, equals(1));
      expect(maleVoices.first.name, contains('male_1'));

      // 4 total voices: 1 female, 1 male, 2 with unknown gender metadata
      expect(unknownVoices.length, equals(4));
    });

    test('strictly leaves gender unknown when engine metadata is missing without guessing by name', () async {
      await service.initialize();

      // "Karen" is a female name colloquially, but has NO gender field in platform metadata
      final karenVoice = service.availableVoices.firstWhere((v) => v.name == 'Karen');
      expect(karenVoice.gender, equals(TtsVoiceGender.unknown));

      // Urdu voice with no gender field
      final urduVoice = service.availableVoices.firstWhere((v) => v.name.startsWith('ur-pk'));
      expect(urduVoice.gender, equals(TtsVoiceGender.unknown));
    });

    test('selects voice by verified TtsVoice model', () async {
      await service.initialize();

      final targetVoice = service.availableVoices.first;
      final success = await service.selectVoice(targetVoice);

      expect(success, isTrue);
      expect(service.selectedVoice, equals(targetVoice));
      expect(adapter.lastVoice?['name'], equals(targetVoice.name));
    });

    test('selects voice by name', () async {
      await service.initialize();

      final success = await service.selectVoiceByName('Karen');

      expect(success, isTrue);
      expect(service.selectedVoice?.name, equals('Karen'));
      expect(adapter.lastVoice?['name'], equals('Karen'));
    });

    test('selects voice by identifier', () async {
      await service.initialize();

      final success = await service.selectVoiceByIdentifier('com.apple.voice.en-US.Alex');

      expect(success, isTrue);
      expect(service.selectedVoice?.name, contains('male_1'));
      expect(adapter.lastVoice?['identifier'], equals('com.apple.voice.en-US.Alex'));
    });

    test('rejects unavailable voice by name with error', () async {
      await service.initialize();

      TtsError? error;
      service.onError = (e) => error = e;

      final success = await service.selectVoiceByName('NonExistentVoice_XYZ');

      expect(success, isFalse);
      expect(error?.code, equals('unavailable_voice'));
      expect(error?.message, contains('NonExistentVoice_XYZ'));
    });

    test('clears voice and resets to default', () async {
      await service.initialize();
      await service.selectVoiceByName('Karen');
      expect(service.selectedVoice, isNotNull);

      await service.clearVoice();

      expect(adapter.clearVoiceCount, equals(1));
      expect(service.selectedVoice, isNull);
    });
  });

  group('TtsService - Speech Parameter Range Validation', () {
    test('sets valid speech rate within 0.0 to 1.0', () async {
      await service.initialize();

      await service.setSpeechRate(0.8);
      expect(service.speechRate, equals(0.8));
      expect(adapter.lastSpeechRate, equals(0.8));

      await service.setSpeechRate(0.0);
      expect(service.speechRate, equals(0.0));

      await service.setSpeechRate(1.0);
      expect(service.speechRate, equals(1.0));
    });

    test('throws ArgumentError on invalid speech rate (<0.0 or >1.0)', () async {
      await service.initialize();

      expect(() => service.setSpeechRate(-0.1), throwsArgumentError);
      expect(() => service.setSpeechRate(1.1), throwsArgumentError);
    });

    test('sets valid volume within 0.0 to 1.0', () async {
      await service.initialize();

      await service.setVolume(0.5);
      expect(service.volume, equals(0.5));
      expect(adapter.lastVolume, equals(0.5));
    });

    test('throws ArgumentError on invalid volume (<0.0 or >1.0)', () async {
      await service.initialize();

      expect(() => service.setVolume(-0.01), throwsArgumentError);
      expect(() => service.setVolume(1.05), throwsArgumentError);
    });

    test('sets valid pitch within 0.5 to 2.0', () async {
      await service.initialize();

      await service.setPitch(1.5);
      expect(service.pitch, equals(1.5));
      expect(adapter.lastPitch, equals(1.5));
    });

    test('throws ArgumentError on invalid pitch (<0.5 or >2.0)', () async {
      await service.initialize();

      expect(() => service.setPitch(0.49), throwsArgumentError);
      expect(() => service.setPitch(2.01), throwsArgumentError);
    });
  });

  group('TtsService - Disposal Safety', () {
    test('disposes cleanly and stops active playback', () async {
      await service.speak('To be disposed');
      expect(service.state, equals(TtsServiceState.speaking));

      await service.dispose();

      expect(service.isDisposed, isTrue);
      expect(service.state, equals(TtsServiceState.disposed));
      expect(adapter.stopCount, equals(1));
    });

    test('throws StateError on operations after disposal', () async {
      await service.dispose();

      expect(() => service.initialize(), throwsStateError);
      expect(() => service.speak('After dispose'), throwsStateError);
      expect(() => service.pause(), throwsStateError);
      expect(() => service.resume(), throwsStateError);
      expect(() => service.setLanguage('en-US'), throwsStateError);
      expect(() => service.setSpeechRate(0.5), throwsStateError);
      expect(() => service.setVolume(1.0), throwsStateError);
      expect(() => service.setPitch(1.0), throwsStateError);
    });
  });

  group('TtsService - Dynamic Discovery & Web Fallback Handling', () {
    test('handles empty initial discovery followed by successful re-discovery via refreshDiscovery', () async {
      final mockAdapter = MockTtsAdapter(languages: [], voices: []);
      final tts = TtsService(adapter: mockAdapter);

      await tts.initialize();
      expect(tts.state, equals(TtsServiceState.ready));
      expect(tts.supportedLanguages, isEmpty);
      expect(tts.availableVoices, isEmpty);

      // Now browser voices populate
      mockAdapter.mockLanguages = ['en-US', 'ur-PK'];
      mockAdapter.mockVoices = [
        {'name': 'Google US English', 'locale': 'en-US'}
      ];

      await tts.refreshDiscovery();
      expect(tts.supportedLanguages, contains('en-US'));
      expect(tts.supportedLanguages, contains('ur-PK'));
      expect(tts.availableVoices.length, equals(1));
    });

    test('re-querying initialize triggers discovery if supportedLanguages was empty', () async {
      final mockAdapter = MockTtsAdapter(languages: [], voices: []);
      final tts = TtsService(adapter: mockAdapter);

      await tts.initialize();
      expect(tts.supportedLanguages, isEmpty);

      mockAdapter.mockLanguages = ['en-US'];
      await tts.initialize();
      expect(tts.supportedLanguages, contains('en-US'));
    });

    test('strictly does NOT claim Pashto voice support when engine reports empty languages', () {
      final mockAdapter = MockTtsAdapter(languages: [], voices: []);
      final tts = TtsService(adapter: mockAdapter);

      expect(tts.isLanguageSupported('ps-AF'), isFalse);
      expect(tts.isLanguageSupported('ps'), isFalse);
    });
  });
}
