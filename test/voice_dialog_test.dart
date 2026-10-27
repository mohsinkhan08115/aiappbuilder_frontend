import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:aiappbuilder/core/components/voice_dialog.dart';
import 'package:aiappbuilder/data/services/api_service.dart';
import 'package:aiappbuilder/data/services/audio_permission_service.dart';
import 'package:aiappbuilder/data/services/speech_service.dart';
import 'package:aiappbuilder/data/services/tts_service.dart';
import 'package:aiappbuilder/data/services/voice_language_service.dart';
import 'package:aiappbuilder/features/chat/view/chat_screen.dart';

extension WidgetTesterVoiceX on WidgetTester {
  Future<void> pumpVoice([Duration duration = const Duration(milliseconds: 50)]) async {
    await pump(duration);
    await pump();
  }

  Future<void> tapVisible(Finder finder) async {
    await ensureVisible(finder);
    await pumpVoice();
    await tap(finder);
    await pumpVoice();
  }
}

class MockPermissionHandlerDelegate implements PermissionHandlerDelegate {
  ph.PermissionStatus status;
  int checkCount = 0;
  int requestCount = 0;
  int openSettingsCount = 0;

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
  Future<bool> openAppSettings() async {
    openSettingsCount++;
    return true;
  }
}

class MockSpeechRecognitionAdapter implements SpeechRecognitionAdapter {
  bool available;
  bool listening = false;
  int listenCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  int disposeCount = 0;
  String? lastListenLocale;

  void Function(String status)? statusCallback;
  void Function(SpeechResult result)? resultCallback;
  void Function(double soundLevel)? soundLevelCallback;
  void Function(SpeechError error)? errorCallback;

  MockSpeechRecognitionAdapter({this.available = true});

  @override
  bool get isAvailable => available;

  @override
  bool get isListening => listening;

  @override
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(SpeechError error)? onError,
  }) async {
    statusCallback = onStatus;
    errorCallback = onError;
    return available;
  }

  void simulateStatus(String status) {
    statusCallback?.call(status);
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
    listening = true;
    lastListenLocale = localeId;
    resultCallback = onResult;
    soundLevelCallback = onSoundLevelChange;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    listening = false;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    listening = false;
  }

  @override
  Future<List<stt.LocaleName>> getLocales() async => [
        stt.LocaleName('en_US', 'English (United States)'),
        stt.LocaleName('ur_PK', 'Urdu (Pakistan)'),
      ];

  @override
  Future<stt.LocaleName?> getSystemLocale() async =>
      stt.LocaleName('en_US', 'English (United States)');

  @override
  Future<void> dispose() async {
    disposeCount++;
    listening = false;
  }
}

class MockTtsAdapter implements TtsAdapter {
  int speakCount = 0;
  int stopCount = 0;
  String? lastSpokenText;
  String? lastLanguage;
  bool shouldFailSpeak = false;
  List<dynamic> mockLanguages;

  VoidCallback? startHandler;
  VoidCallback? completionHandler;
  VoidCallback? cancelHandler;

  MockTtsAdapter({List<dynamic>? languages})
      : mockLanguages = languages ?? ['en-US', 'ur-PK'];

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => true;

  @override
  Future<dynamic> speak(String text) async {
    speakCount++;
    lastSpokenText = text;
    if (shouldFailSpeak) {
      throw Exception('Simulated TTS playback failure');
    }
    startHandler?.call();
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    stopCount++;
    completionHandler?.call();
    return 1;
  }

  @override
  Future<dynamic> pause() async => 1;

  @override
  Future<dynamic> resume() async => 1;

  @override
  Future<dynamic> setLanguage(String language) async {
    lastLanguage = language;
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async => 1;

  @override
  Future<dynamic> clearVoice() async => 1;

  @override
  Future<dynamic> getLanguages() async => mockLanguages;

  @override
  Future<dynamic> getVoices() async => [];

  @override
  Future<dynamic> isLanguageAvailable(String language) async =>
      mockLanguages.contains(language);

  @override
  void setStartHandler(VoidCallback callback) => startHandler = callback;

  @override
  void setCompletionHandler(VoidCallback callback) =>
      completionHandler = callback;

  @override
  void setPauseHandler(VoidCallback callback) {}

  @override
  void setContinueHandler(VoidCallback callback) {}

  @override
  void setCancelHandler(VoidCallback callback) => cancelHandler = callback;

  @override
  void setProgressHandler(
      void Function(String text, int start, int end, String word) callback) {}

  @override
  void setErrorHandler(void Function(dynamic message) handler) {}
}

class FakeApiService extends ApiService {
  int sendCount = 0;
  String? lastPrompt;
  String? lastConversationId;
  String? lastSystemInstruction;
  String responseText;
  String returnConversationId;
  List<SourceCitation> returnSources;
  List<String> returnSearchQueries;
  bool shouldThrow;
  Completer<ChatResponse>? responseCompleter;
  CancelToken? lastCancelToken;

  FakeApiService({
    this.responseText = 'Here is the AI generated solution.',
    this.returnConversationId = 'conv-voice-123',
    this.returnSources = const [],
    this.returnSearchQueries = const [],
    this.shouldThrow = false,
  });

  @override
  Future<ChatResponse> sendChatMessage(
    String message, {
    String? conversationId,
    String? systemInstruction,
    CancelToken? cancelToken,
  }) async {
    sendCount++;
    lastPrompt = message;
    lastConversationId = conversationId;
    lastSystemInstruction = systemInstruction;
    lastCancelToken = cancelToken;

    if (shouldThrow) {
      throw Exception('Network timeout connecting to AI backend');
    }

    if (responseCompleter != null) {
      if (cancelToken != null) {
        return await Future.any([
          responseCompleter!.future,
          cancelToken.whenCancel.then((e) => throw e),
        ]);
      }
      return await responseCompleter!.future;
    }

    return ChatResponse(
      response: responseText,
      conversationId: returnConversationId,
      sources: returnSources,
      searchQueries: returnSearchQueries,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPermissionHandlerDelegate permissionDelegate;
  late AudioPermissionService permissionService;
  late MockSpeechRecognitionAdapter speechAdapter;
  late SpeechService speechService;
  late MockTtsAdapter ttsAdapter;
  late TtsService ttsService;
  late FakeApiService apiService;

  setUp(() {
    ChatSessionMemory.reset();
    permissionDelegate = MockPermissionHandlerDelegate();
    permissionService = AudioPermissionService(delegate: permissionDelegate);
    speechAdapter = MockSpeechRecognitionAdapter();
    speechService = SpeechService(
      adapter: speechAdapter,
      permissionService: permissionService,
    );
    ttsAdapter = MockTtsAdapter();
    ttsService = TtsService(adapter: ttsAdapter);
    apiService = FakeApiService();
  });

  Future<void> openDialog(
    WidgetTester tester, {
    VoidCallback? onReturnToText,
    void Function(String prompt, String response, String? conversationId)?
        onMessageExchanged,
    String? conversationId,
    VoiceLanguage initialLanguage = VoiceLanguage.unknown,
    Duration autoSendDelay = const Duration(seconds: 3),
    bool enableBargeIn = true,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => VoiceDialog(
                onReturnToText: onReturnToText ?? () {},
                apiService: apiService,
                speechService: speechService,
                ttsService: ttsService,
                permissionService: permissionService,
                conversationId: conversationId,
                initialLanguage: initialLanguage,
                autoSendDelay: autoSendDelay,
                enableBargeIn: enableBargeIn,
                onMessageExchanged: onMessageExchanged,
              ),
            ),
            child: const Text('Launch Voice Dialog'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Launch Voice Dialog'));
    await tester.pumpVoice();
  }

  group('VoiceDialog - Microphone & Recognition Flow', () {
    testWidgets('tap microphone requests permission, initializes STT, and starts listening', (tester) async {
      await openDialog(tester);

      expect(find.text('Talk to AI'), findsWidgets);
      expect(find.text('Ready'), findsOneWidget);

      // Tap microphone button
      await tester.tapVisible(find.byIcon(Icons.mic));

      expect(permissionDelegate.checkCount, greaterThanOrEqualTo(1));
      expect(speechAdapter.listenCount, equals(1));
      expect(find.text('Listening to you...'), findsOneWidget);
      expect(find.text('Listening'), findsOneWidget);
    });

    testWidgets('shows interim transcripts live, then transitions to review on final result', (tester) async {
      await openDialog(tester);

      // Start listening
      await tester.tapVisible(find.byIcon(Icons.mic));

      // Emit interim result
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Create a Flutter', isFinal: false),
      );
      await tester.pumpVoice();

      expect(find.text('Create a Flutter'), findsOneWidget);
      expect(find.text('Listening to you...'), findsOneWidget);

      // Emit final result
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Create a Flutter login page', isFinal: true),
      );
      await tester.pumpVoice();

      expect(find.text('Create a Flutter login page'), findsOneWidget);
      expect(find.text('Review your message'), findsOneWidget);
      expect(find.text('Send to AI'), findsOneWidget);
    });

    testWidgets('stopping recording with empty speech shows retry message without crashing', (tester) async {
      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));

      // Tap Stop Recording with no speech
      await tester.tapVisible(find.text('Stop Recording'));

      expect(find.text('No speech was detected. Please try again.'), findsOneWidget);
      expect(find.text('Send to AI'), findsNothing);
    });

    testWidgets('cancel button aborts listening and clears interim transcript', (tester) async {
      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));

      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Discard me', isFinal: false),
      );
      await tester.pumpVoice();
      expect(find.text('Discard me'), findsOneWidget);

      await tester.tapVisible(find.text('Cancel'));

      expect(speechAdapter.cancelCount, equals(1));
      expect(find.text('Discard me'), findsNothing);
      expect(find.text('Ready'), findsOneWidget);
    });
  });

  group('VoiceDialog - Permissions and STT Errors', () {
    testWidgets('handles denied microphone permission gracefully with error message', (tester) async {
      permissionDelegate.status = ph.PermissionStatus.denied;

      await openDialog(tester);
      await tester.tapVisible(find.byIcon(Icons.mic));

      expect(speechAdapter.listenCount, equals(0));
      expect(find.text('Microphone permission is required to use voice input.'), findsOneWidget);
    });

    testWidgets('handles permanently denied permission with Settings button', (tester) async {
      permissionDelegate.status = ph.PermissionStatus.permanentlyDenied;

      await openDialog(tester);
      await tester.tapVisible(find.byIcon(Icons.mic));

      expect(find.text('Microphone permission is permanently denied. Please enable it in system settings.'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      await tester.tapVisible(find.text('Settings'));

      expect(permissionDelegate.openSettingsCount, equals(1));
    });

    testWidgets('handles speech recognition adapter error cleanly', (tester) async {
      await openDialog(tester);
      await tester.tapVisible(find.byIcon(Icons.mic));

      speechAdapter.errorCallback?.call(
        const SpeechError(message: 'Engine recognition timeout'),
      );
      await tester.pumpVoice();

      expect(find.text('Engine recognition timeout'), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
    });
  });

  group('VoiceDialog - Existing AI Chat Integration & TTS Flow', () {
    testWidgets('sends finalized transcript to ApiService and speaks returned response with TTS', (tester) async {
      String? callbackPrompt;
      String? callbackResponse;
      String? callbackConvId;

      await openDialog(
        tester,
        conversationId: 'existing-conv-999',
        onMessageExchanged: (p, r, c) {
          callbackPrompt = p;
          callbackResponse = r;
          callbackConvId = c;
        },
      );

      // 1. Listen and transcribe
      await tester.tapVisible(find.byIcon(Icons.mic));

      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Plan a weather app in Flutter', isFinal: true),
      );
      await tester.pumpVoice();

      // 2. Submit to AI
      await tester.tapVisible(find.text('Send to AI'));

      // Verifications
      expect(apiService.sendCount, equals(1));
      expect(apiService.lastPrompt, equals('Plan a weather app in Flutter'));
      expect(apiService.lastConversationId, equals('existing-conv-999'));
      expect(apiService.lastSystemInstruction, contains('English'));

      // Callback notified
      expect(callbackPrompt, equals('Plan a weather app in Flutter'));
      expect(callbackResponse, equals('Here is the AI generated solution.'));
      expect(callbackConvId, equals('conv-voice-123'));

      // AI response rendered visibly
      expect(find.text('Here is the AI generated solution.'), findsOneWidget);

      // TTS spoken
      expect(ttsAdapter.speakCount, equals(1));
      expect(ttsAdapter.lastSpokenText, equals('Here is the AI generated solution.'));

      // In Speaking state with Stop Speaking button
      expect(find.text('Stop Speaking'), findsOneWidget);
    });

    testWidgets('preserves chat history in ChatSessionMemory across conversation', (tester) async {
      await openDialog(tester);

      // Start, transcribe, send
      apiService.returnSources = const [
        SourceCitation(
          title: 'Flutter Docs',
          url: 'https://docs.flutter.dev',
          domain: 'docs.flutter.dev',
          publishedDate: '2026-10-22',
        ),
      ];
      apiService.returnSearchQueries = const ['flutter voice assistant'];
      await tester.tapVisible(find.byIcon(Icons.mic));

      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Test conversation history', isFinal: true),
      );
      await tester.pumpVoice();

      await tester.tapVisible(find.text('Send to AI'));

      // Verify ChatSessionMemory was populated
      expect(ChatSessionMemory.threads, isNotNull);
      expect(ChatSessionMemory.threads!.isNotEmpty, isTrue);

      final thread = ChatSessionMemory.threads!.first;
      expect(thread.conversationId, equals('conv-voice-123'));
      expect(thread.messages.length, equals(2));
      expect(thread.messages[0].isUser, isTrue);
      expect(thread.messages[0].text, equals('Test conversation history'));
      expect(thread.messages[1].isUser, isFalse);
      expect(thread.messages[1].text, equals('Here is the AI generated solution.'));
      expect(thread.messages[1].sources, hasLength(1));
      expect(thread.messages[1].sources.first.title, equals('Flutter Docs'));
      expect(thread.messages[1].sources.first.url, equals('https://docs.flutter.dev'));
      expect(thread.messages[1].searchQueries, equals(['flutter voice assistant']));
    });

    testWidgets('API failure displays error message and does NOT trigger TTS', (tester) async {
      apiService.shouldThrow = true;

      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));

      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Failing prompt', isFinal: true),
      );
      await tester.pumpVoice();

      await tester.tapVisible(find.text('Send to AI'));

      expect(apiService.sendCount, equals(1));
      expect(ttsAdapter.speakCount, equals(0)); // Never called TTS
      expect(find.textContaining('Network timeout connecting to AI backend'), findsOneWidget);
      // User transcript is preserved for retry
      expect(find.text('Failing prompt'), findsOneWidget);
    });

    testWidgets('TTS failure does NOT hide or lose the AI response', (tester) async {
      ttsAdapter.shouldFailSpeak = true;

      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));

      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Trigger TTS error', isFinal: true),
      );
      await tester.pumpVoice();

      await tester.tapVisible(find.text('Send to AI'));

      // AI response is still visibly displayed
      expect(find.text('Here is the AI generated solution.'), findsOneWidget);
      expect(apiService.sendCount, equals(1));
      expect(ttsAdapter.speakCount, equals(1));
    });

    testWidgets('stop speaking button halts active audio playback', (tester) async {
      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));

      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Speak and stop', isFinal: true),
      );
      await tester.pumpVoice();

      await tester.tapVisible(find.text('Send to AI'));

      expect(find.text('Stop Speaking'), findsOneWidget);

      await tester.tapVisible(find.text('Stop Speaking'));

      expect(ttsAdapter.stopCount, greaterThanOrEqualTo(1));
      expect(find.text('Stop Speaking'), findsNothing);
    });
  });

  group('VoiceDialog - Multilingual Behavior: Urdu, English & Pashto', () {
    testWidgets('detects Urdu speech, instructs AI to reply in Urdu, and speaks with ur-PK TTS', (tester) async {
      apiService.responseText = 'یہ آپ کا حل ہے'; // AI responds in Urdu

      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));

      // Speech in Urdu with unique characters
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'لاگ ان اسکرین کیسے بنائیں', isFinal: true),
      );
      await tester.pumpVoice();

      // Verify Urdu detection badge
      expect(find.text('Urdu (اردو)'), findsWidgets);

      // Send to AI
      await tester.tapVisible(find.text('Send to AI'));

      // System instruction contains Urdu directive
      expect(apiService.sendCount, equals(1));
      expect(apiService.lastSystemInstruction, contains('Urdu (اردو)'));
      expect(apiService.lastPrompt, equals('لاگ ان اسکرین کیسے بنائیں'));

      // TTS configured for Urdu
      expect(ttsAdapter.lastLanguage, equals('ur-PK'));
      expect(ttsAdapter.speakCount, equals(1));
      expect(ttsAdapter.lastSpokenText, equals('یہ آپ کا حل ہے'));
      expect(find.text('یہ آپ کا حل ہے'), findsOneWidget);
    });

    testWidgets('detects Pashto speech, instructs AI in Pashto, and safely handles unsupported Pashto TTS', (tester) async {
      apiService.responseText = 'دلته ستاسو حل دی'; // AI responds in Pashto

      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));

      // Speech in Pashto with unique character 'ښ'
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'پښتو ژبه کې مرسته وکړئ', isFinal: true),
      );
      await tester.pumpVoice();

      // Verify Pashto detection
      expect(find.text('Pashto (پښتو)'), findsWidgets);

      // Send to AI
      await tester.tapVisible(find.text('Send to AI'));

      // System instruction contains Pashto directive
      expect(apiService.sendCount, equals(1));
      expect(apiService.lastSystemInstruction, contains('Pashto (پښتو)'));

      // Because Pashto is not in ttsAdapter.mockLanguages ('en-US', 'ur-PK'),
      // TTS playback must NOT be triggered with wrong voice
      expect(ttsAdapter.speakCount, equals(0));

      // AI response is prominently displayed in text
      expect(find.text('دلته ستاسو حل دی'), findsOneWidget);

      // Clear playback-unavailable banner is shown
      expect(find.textContaining('Voice playback is not supported on this device for Pashto'), findsOneWidget);
    });

    testWidgets('allows manual language override via initialLanguage or language selector', (tester) async {
      await openDialog(
        tester,
        initialLanguage: VoiceLanguage.urdu,
      );

      // Tap mic
      await tester.tapVisible(find.byIcon(Icons.mic));

      // Requested locale should be ur_PK
      expect(speechAdapter.lastListenLocale, equals('ur_PK'));
    });
  });

  group('VoiceDialog - Navigation and Cleanup', () {
    testWidgets('Return to text invokes callback and dismisses dialog', (tester) async {
      bool returnToTextCalled = false;

      await openDialog(
        tester,
        onReturnToText: () => returnToTextCalled = true,
      );

      await tester.tapVisible(find.text('Return to text'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(returnToTextCalled, isTrue);
      expect(find.byType(VoiceDialog), findsNothing);
    });

    testWidgets('End button dismisses dialog', (tester) async {
      await openDialog(tester);

      expect(find.byType(VoiceDialog), findsOneWidget);

      await tester.tapVisible(find.text('End'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byType(VoiceDialog), findsNothing);
    });
  });

  group('VoiceDialog - Regression Tests: Chrome Recognition & Manual TTS Playback', () {
    testWidgets('recognition ending with doneNoResult transitions out of listening to error retry state', (tester) async {
      await openDialog(tester);

      // Start listening
      await tester.tapVisible(find.byIcon(Icons.mic));
      expect(find.text('Listening to you...'), findsOneWidget);

      // Web plugin signals doneNoResult
      speechAdapter.simulateStatus('doneNoResult');
      await tester.pumpVoice();

      // State is no longer listening; shows recoverable message
      expect(find.text('Listening to you...'), findsNothing);
      expect(find.text('No speech was detected. Please try again.'), findsOneWidget);

      // Re-recording is fully operational
      await tester.tapVisible(find.byIcon(Icons.mic));
      expect(find.text('Listening to you...'), findsOneWidget);
    });

    testWidgets('automatic recognition termination with non-empty transcript transitions to review', (tester) async {
      await openDialog(tester);

      // Start listening
      await tester.tapVisible(find.byIcon(Icons.mic));

      // Interim speech received
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Build a calculator', isFinal: false),
      );
      await tester.pumpVoice();

      // Recognition ends automatically (e.g. done)
      speechAdapter.simulateStatus('done');
      await tester.pumpVoice();

      expect(find.text('Review your message'), findsOneWidget);
      expect(find.text('Build a calculator'), findsOneWidget);
      expect(find.text('Send to AI'), findsOneWidget);
    });

    testWidgets('shows manual Play AI Voice button after AI response, enabling manual playback retry', (tester) async {
      await openDialog(tester);

      // Listen and produce speech
      await tester.tapVisible(find.byIcon(Icons.mic));
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Generate a chart widget', isFinal: true),
      );
      await tester.pumpVoice();

      // Send to AI
      await tester.tapVisible(find.text('Send to AI'));
      await tester.pumpVoice();

      // TTS completes speaking
      ttsAdapter.completionHandler?.call();
      await tester.pumpVoice();

      // Both Play AI Voice and Speak Again buttons are present
      expect(find.text('Play AI Voice'), findsOneWidget);
      expect(find.text('Speak Again'), findsOneWidget);
      expect(find.text('Here is the AI generated solution.'), findsOneWidget);

      final initialSpeakCount = ttsAdapter.speakCount;

      // Click manual Play AI Voice button
      await tester.tapVisible(find.text('Play AI Voice'));
      await tester.pumpVoice();

      expect(ttsAdapter.speakCount, equals(initialSpeakCount + 1));
      expect(ttsAdapter.lastSpokenText, equals('Here is the AI generated solution.'));
    });

    testWidgets('dialog disposal cancels active speech recognition safely without exceptions', (tester) async {
      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));
      expect(speechAdapter.isListening, isTrue);

      // Dismiss dialog
      await tester.tapVisible(find.text('End'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(speechAdapter.cancelCount, equals(1));
    });
  });

  group('VoiceDialog - Auto-Send: 3-second inactivity timer', () {
    testWidgets('auto-submits after 3 seconds of inactivity following a final result', (tester) async {
      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));

      // Final speech result arrives
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Build a login screen', isFinal: true),
      );
      await tester.pumpVoice();

      // Should now be in review state with pending auto-send notice
      expect(find.text('Review your message'), findsOneWidget);
      expect(find.textContaining('Sending in 3 seconds'), findsOneWidget);

      // Advance time past the 3-second timer
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      // API should have been called exactly once with the transcript
      expect(apiService.sendCount, equals(1));
      expect(apiService.lastPrompt, equals('Build a login screen'));
    });

    testWidgets('timer is reset when an interim result arrives (user still speaking)', (tester) async {
      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));

      // First final result — starts timer
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Build a', isFinal: true),
      );
      await tester.pumpVoice();
      expect(find.textContaining('Sending in 3 seconds'), findsOneWidget);

      // Interim result arrives 1 second later — cancels timer
      await tester.pump(const Duration(seconds: 1));
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Build a login screen', isFinal: false),
      );
      await tester.pump();

      // Timer cancelled; no auto-send notice
      expect(find.textContaining('Sending in 3 seconds'), findsNothing);

      // Advance another 3 seconds — still no submission (timer was cancelled)
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(apiService.sendCount, equals(0));
    });

    testWidgets('does not auto-submit an empty or whitespace-only transcript', (tester) async {
      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));

      // Final result with empty text — goes to error, no auto-send
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: '', isFinal: true),
      );
      await tester.pumpVoice();

      expect(find.textContaining('Sending in 3 seconds'), findsNothing);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(apiService.sendCount, equals(0));
    });

    testWidgets('does not auto-submit on interim (non-final) results only', (tester) async {
      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));

      // Only interim results — timer must NOT start
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Build a calculator', isFinal: false),
      );
      await tester.pumpVoice();

      expect(find.textContaining('Sending in 3 seconds'), findsNothing);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(apiService.sendCount, equals(0));
    });

    testWidgets('manual Send and timer do not cause duplicate API calls', (tester) async {
      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));

      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Generate a chart', isFinal: true),
      );
      await tester.pumpVoice();

      // Manually tap Send before the 3-second timer fires
      await tester.tapVisible(find.text('Send to AI'));
      await tester.pumpVoice();

      // Advance past 3 seconds — timer should have been cancelled
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      // Exactly one API call regardless of timer
      expect(apiService.sendCount, equals(1));
    });

    testWidgets('closing the dialog cancels the pending auto-send timer', (tester) async {
      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));

      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Build a signup form', isFinal: true),
      );
      await tester.pumpVoice();
      expect(find.textContaining('Sending in 3 seconds'), findsOneWidget);

      // Dismiss dialog before timer fires
      await tester.tapVisible(find.text('End'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // Dialog is gone
      expect(find.byType(VoiceDialog), findsNothing);

      // Advance time — no API call should occur
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(apiService.sendCount, equals(0));
    });

    testWidgets('Cancel Auto-send button cancels the timer and hides the notice', (tester) async {
      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));

      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Build a dashboard', isFinal: true),
      );
      await tester.pumpVoice();

      expect(find.textContaining('Sending in 3 seconds'), findsOneWidget);
      expect(find.text('Cancel Auto-send'), findsOneWidget);

      // User taps Cancel Auto-send
      await tester.tapVisible(find.text('Cancel Auto-send'));
      await tester.pumpVoice();

      expect(find.textContaining('Sending in 3 seconds'), findsNothing);
      expect(find.text('Cancel Auto-send'), findsNothing);

      // Advance time — no auto-submission
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(apiService.sendCount, equals(0));
    });

    testWidgets('failed API request does not auto-retry', (tester) async {
      apiService.shouldThrow = true;

      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));

      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Build something', isFinal: true),
      );
      await tester.pumpVoice();

      // Let timer fire
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      // One attempt, then error state — no repeated retry
      expect(apiService.sendCount, equals(1));
      expect(find.textContaining('AI request failed'), findsOneWidget);
      expect(find.textContaining('Sending in 3 seconds'), findsNothing);

      // Wait even longer — still no second attempt
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(apiService.sendCount, equals(1));
    });

    testWidgets('starting a new recording cancels the pending auto-send timer', (tester) async {
      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));

      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'First message', isFinal: true),
      );
      await tester.pumpVoice();

      expect(find.textContaining('Sending in 3 seconds'), findsOneWidget);

      // User taps Re-record to start a new recording session
      await tester.tapVisible(find.text('Re-record'));
      await tester.pumpVoice();

      expect(find.textContaining('Sending in 3 seconds'), findsNothing);

      // Advance time — first auto-send timer should not fire
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(apiService.sendCount, equals(0));
    });
  });

  group('VoiceDialog - Barge-In & Low Latency Turn Detection', () {
    testWidgets('default autoSendDelay is 1 second and submits after 1-second countdown', (tester) async {
      await openDialog(
        tester,
        autoSendDelay: VoiceDialog.defaultAutoSendDelay,
      );

      await tester.tapVisible(find.byIcon(Icons.mic));

      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Build a calculator', isFinal: true),
      );
      await tester.pumpVoice();

      expect(find.textContaining('Sending in 1 second'), findsOneWidget);

      // Advance past the 1-second timer
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump();

      expect(apiService.sendCount, equals(1));
      expect(apiService.lastPrompt, equals('Build a calculator'));
    });

    testWidgets('user speech during speaking state immediately halts TTS audio playback (Barge-In)', (tester) async {
      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Tell me a joke', isFinal: true),
      );
      await tester.pumpVoice();

      // Trigger send
      await tester.tapVisible(find.text('Send to AI'));
      await tester.pumpVoice();

      // AI response is playing TTS
      expect(find.text('Stop Speaking'), findsOneWidget);
      expect(ttsAdapter.stopCount, equals(0));

      // User speaks while AI is speaking (Barge-In)
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Wait stop talking', isFinal: false),
      );
      await tester.pumpVoice();

      // TTS audio was stopped immediately
      expect(ttsAdapter.stopCount, greaterThanOrEqualTo(1));
      expect(find.text('Stop Speaking'), findsNothing);
      // State switched back to listening and displays the new user utterance
      expect(find.text('Wait stop talking'), findsOneWidget);
      expect(find.text('Listening to you...'), findsOneWidget);
    });

    testWidgets('user speech during processing state cancels in-flight backend request and discards stale response', (tester) async {
      final completer = Completer<ChatResponse>();
      apiService.responseCompleter = completer;

      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Long running request', isFinal: true),
      );
      await tester.pumpVoice();

      // Submit prompt — enters processing
      await tester.tapVisible(find.text('Send to AI'));
      await tester.pumpVoice();

      expect(find.text('AI is thinking...'), findsOneWidget);
      expect(apiService.lastCancelToken, isNotNull);
      expect(apiService.lastCancelToken!.isCancelled, isFalse);

      // User interrupts while still processing
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Never mind cancel that', isFinal: true),
      );
      await tester.pumpVoice();

      // In-flight request was cancelled
      expect(apiService.lastCancelToken!.isCancelled, isTrue);

      // Complete the pending backend request late
      completer.complete(ChatResponse(
        response: 'Stale response that should be ignored',
        conversationId: 'stale-conv',
      ));
      await tester.pumpVoice();

      // Stale response was discarded — not spoken, not saved in history
      expect(ttsAdapter.speakCount, equals(0));
      expect(find.text('Stale response that should be ignored'), findsNothing);
      expect(find.text('Never mind cancel that'), findsOneWidget);
    });

    testWidgets('echo filtering ignores speaker audio feedback but triggers barge-in on distinct user speech', (tester) async {
      await openDialog(tester);

      await tester.tapVisible(find.byIcon(Icons.mic));
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'What is Flutter?', isFinal: true),
      );
      await tester.pumpVoice();

      await tester.tapVisible(find.text('Send to AI'));
      await tester.pumpVoice();

      expect(find.text('Stop Speaking'), findsOneWidget);
      final initialStopCount = ttsAdapter.stopCount;

      // Echo of the AI response ('Here is the AI generated solution.')
      // Spoken words are 2 words and contained within AI speech
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Here is', isFinal: false),
      );
      await tester.pumpVoice();

      // Echo filter prevented self-interruption — still speaking
      expect(ttsAdapter.stopCount, equals(initialStopCount));
      expect(find.text('Stop Speaking'), findsOneWidget);

      // Now user actually interrupts with distinct words
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Actually show me Python', isFinal: false),
      );
      await tester.pumpVoice();

      // Barge-in triggered
      expect(ttsAdapter.stopCount, greaterThan(initialStopCount));
      expect(find.text('Stop Speaking'), findsNothing);
      expect(find.text('Actually show me Python'), findsOneWidget);
    });

    testWidgets('interim speech results reset the auto-send timer so user pause does not cut them off', (tester) async {
      await openDialog(
        tester,
        autoSendDelay: const Duration(seconds: 2),
      );

      await tester.tapVisible(find.byIcon(Icons.mic));

      // Final result starts 2s countdown
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Create a screen', isFinal: true),
      );
      await tester.pumpVoice();
      expect(find.textContaining('Sending in 2 seconds'), findsOneWidget);

      // Advance 1 second — user continues speaking with an interim result
      await tester.pump(const Duration(seconds: 1));
      speechAdapter.resultCallback?.call(
        const SpeechResult(words: 'Create a screen with blue buttons', isFinal: false),
      );
      await tester.pumpVoice();

      // Countdown cancelled because user is still talking
      expect(find.textContaining('Sending in 2 seconds'), findsNothing);

      // Advance another 2 seconds — no premature auto-submission occurred
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(apiService.sendCount, equals(0));
    });

    testWidgets('TTS is pre-warmed during dialog initialization', (tester) async {
      // Opening dialog kicks off TTS initialization in initState
      await openDialog(tester);
      await tester.pump();

      expect(ttsService.isInitialized, isTrue);
    });
  });
}
