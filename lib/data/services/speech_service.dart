import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'audio_permission_service.dart';

/// Lifecycle and operational state of the speech recognition service.
enum SpeechServiceState {
  uninitialized,
  initializing,
  ready,
  listening,
  stopping,
  error,
  disposed,
}

/// Normalized result of recognized speech containing current words,
/// whether the result is final, and engine confidence.
class SpeechResult {
  final String words;
  final bool isFinal;
  final double confidence;

  const SpeechResult({
    required this.words,
    required this.isFinal,
    this.confidence = 0.0,
  });

  @override
  String toString() => 'SpeechResult(words: "$words", isFinal: $isFinal, confidence: $confidence)';
}

/// Normalized representation of speech recognition errors.
class SpeechError {
  final String message;
  final bool permanent;

  const SpeechError({
    required this.message,
    this.permanent = false,
  });

  @override
  String toString() => 'SpeechError(message: "$message", permanent: $permanent)';
}

/// Abstract adapter seam allowing SpeechService to be tested cleanly in unit tests
/// without requiring physical microphone hardware or real OS speech recognition engines.
abstract class SpeechRecognitionAdapter {
  bool get isAvailable;
  bool get isListening;

  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(SpeechError error)? onError,
  });

  Future<void> listen({
    required void Function(SpeechResult result) onResult,
    String? localeId,
    Duration? listenFor,
    Duration? pauseFor,
    bool partialResults = true,
    void Function(double soundLevel)? onSoundLevelChange,
  });

  Future<void> stop();
  Future<void> cancel();
  Future<List<stt.LocaleName>> getLocales();
  Future<stt.LocaleName?> getSystemLocale();
  Future<void> dispose();
}

/// Production implementation delegating directly to package:speech_to_text.
class DefaultSpeechRecognitionAdapter implements SpeechRecognitionAdapter {
  final stt.SpeechToText _stt;

  DefaultSpeechRecognitionAdapter([stt.SpeechToText? sttInstance])
      : _stt = sttInstance ?? stt.SpeechToText();

  @override
  bool get isAvailable => _stt.isAvailable;

  @override
  bool get isListening => _stt.isListening;

  @override
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(SpeechError error)? onError,
  }) async {
    return await _stt.initialize(
      onStatus: onStatus,
      onError: onError != null
          ? (sttError) => onError(
                SpeechError(
                  message: sttError.errorMsg,
                  permanent: sttError.permanent,
                ),
              )
          : null,
    );
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
    await _stt.listen(
      onResult: (sttResult) {
        onResult(
          SpeechResult(
            words: sttResult.recognizedWords,
            isFinal: sttResult.finalResult,
            confidence: sttResult.confidence,
          ),
        );
      },
      localeId: localeId,
      listenFor: listenFor,
      pauseFor: pauseFor,
      partialResults: partialResults,
      onSoundLevelChange: onSoundLevelChange,
    );
  }

  @override
  Future<void> stop() async {
    await _stt.stop();
  }

  @override
  Future<void> cancel() async {
    await _stt.cancel();
  }

  @override
  Future<List<stt.LocaleName>> getLocales() async {
    return await _stt.locales();
  }

  @override
  Future<stt.LocaleName?> getSystemLocale() async {
    return await _stt.systemLocale();
  }

  @override
  Future<void> dispose() async {
    if (_stt.isListening) {
      await _stt.stop();
    }
  }
}

/// Real, decoupled Speech-to-Text service for the AI App Builder.
///
/// Features:
/// - Verifies and requests microphone permissions exclusively through [AudioPermissionService].
/// - Manages full recognition lifecycle: initialize, listen, stop, cancel, dispose.
/// - Returns interim and final transcripts with live confidence and sound levels.
/// - Dynamic locale discovery: queries available speech recognition locales on the host device.
/// - Validates locale availability before selection (e.g. English, Urdu, Pashto) and falls back safely.
/// - Enforces strict guardrails against duplicate sessions and unhandled platform exceptions.
/// - Zero raw audio persistence or remote transmission.
class SpeechService {
  final SpeechRecognitionAdapter _adapter;
  final AudioPermissionService _permissionService;

  /// Default pause threshold after which the STT engine concludes an utterance.
  /// Reduced from 3 seconds to 1.5 seconds to balance responsiveness without cutting off user pauses.
  static const Duration defaultPauseFor = Duration(milliseconds: 1500);

  SpeechServiceState _state = SpeechServiceState.uninitialized;
  SpeechError? _lastError;
  String _lastWords = '';
  String? _selectedLocaleId;
  List<stt.LocaleName> _supportedLocales = [];

  void Function(SpeechServiceState state)? onStateChanged;
  void Function(SpeechError error)? onError;
  void Function(SpeechResult result)? onResult;
  void Function(double soundLevel)? onSoundLevelChange;

  SpeechService({
    SpeechRecognitionAdapter? adapter,
    AudioPermissionService? permissionService,
  })  : _adapter = adapter ?? DefaultSpeechRecognitionAdapter(),
        _permissionService = permissionService ?? AudioPermissionService();

  SpeechServiceState get state => _state;
  bool get isAvailable => _adapter.isAvailable;
  bool get isListening => _adapter.isListening;
  SpeechError? get lastError => _lastError;
  String get lastRecognizedWords => _lastWords;
  String? get selectedLocaleId => _selectedLocaleId;
  List<stt.LocaleName> get supportedLocales => List.unmodifiable(_supportedLocales);

  void _setState(SpeechServiceState newState) {
    if (_state == SpeechServiceState.disposed || _state == newState) return;
    _state = newState;
    onStateChanged?.call(_state);
  }

  void _setError(SpeechError error) {
    _lastError = error;
    onError?.call(error);
    _setState(SpeechServiceState.error);
  }

  /// Initializes the speech recognition engine.
  ///
  /// Requests microphone permission via [AudioPermissionService]. If granted,
  /// initializes the underlying speech engine and discovers supported locales.
  Future<bool> initialize() async {
    if (_state == SpeechServiceState.disposed) return false;
    if (_state == SpeechServiceState.ready && _adapter.isAvailable) return true;

    _setState(SpeechServiceState.initializing);

    try {
      // 1. Verify and request microphone permission
      final permission = await _permissionService.requestPermission();
      if (!permission.isGranted) {
        _setError(
          SpeechError(
            message: permission.isPermanentlyDenied
                ? 'Microphone permission is permanently denied. Please enable it in system settings.'
                : 'Microphone permission was denied.',
            permanent: permission.isPermanentlyDenied,
          ),
        );
        return false;
      }

      // 2. Initialize adapter
      final initialized = await _adapter.initialize(
        onStatus: (status) {
          if (_state == SpeechServiceState.disposed) return;
          if (status == 'listening') {
            _setState(SpeechServiceState.listening);
          } else if (status == 'notListening' ||
              status == 'done' ||
              status == 'doneNoResult') {
            if (_state == SpeechServiceState.listening ||
                _state == SpeechServiceState.stopping) {
              _setState(SpeechServiceState.ready);
            }
          }
        },
        onError: (error) {
          if (_state == SpeechServiceState.disposed) return;
          _setError(error);
        },
      );

      if (!initialized) {
        _setError(
          const SpeechError(
            message: 'Speech recognition engine could not be initialized on this device.',
            permanent: false,
          ),
        );
        return false;
      }

      // 3. Discover available locales on the device
      try {
        _supportedLocales = await _adapter.getLocales();
        final systemLocale = await _adapter.getSystemLocale();
        _selectedLocaleId ??= systemLocale?.localeId;
      } catch (localeErr) {
        debugPrint('SpeechService: Locale discovery warning: $localeErr');
        _supportedLocales = [];
      }

      _setState(SpeechServiceState.ready);
      return true;
    } catch (e, stack) {
      debugPrint('SpeechService.initialize error: $e\n$stack');
      _setError(SpeechError(message: 'Speech recognition initialization failed: $e'));
      return false;
    }
  }

  /// Checks if a locale is reported as supported by the device speech engine.
  /// Matches exact localeId (e.g. 'en_US', 'ur_PK') or language code prefix (e.g. 'en', 'ur', 'ps').
  bool isLocaleSupported(String localeIdentifier) {
    if (_supportedLocales.isEmpty) return false;
    final target = localeIdentifier.toLowerCase().replaceAll('-', '_');
    return _supportedLocales.any((loc) {
      final locId = loc.localeId.toLowerCase().replaceAll('-', '_');
      return locId == target || locId.startsWith('${target}_');
    });
  }

  /// Selects an active speech recognition locale only if the device speech engine supports it.
  /// Returns `true` if selected, `false` if unsupported.
  bool setLocale(String localeIdentifier) {
    if (isLocaleSupported(localeIdentifier)) {
      // Find the best match
      final target = localeIdentifier.toLowerCase().replaceAll('-', '_');
      final match = _supportedLocales.firstWhere(
        (loc) {
          final locId = loc.localeId.toLowerCase().replaceAll('-', '_');
          return locId == target || locId.startsWith('${target}_');
        },
      );
      _selectedLocaleId = match.localeId;
      return true;
    }
    debugPrint('SpeechService: Locale "$localeIdentifier" is not supported on this device.');
    return false;
  }

  /// Helper checks for target project languages
  bool get isEnglishSupported => isLocaleSupported('en');
  bool get isUrduSupported => isLocaleSupported('ur');
  bool get isPashtoSupported => isLocaleSupported('ps');

  /// Starts listening for speech input.
  ///
  /// Guarantees:
  /// - Initializes the engine if not already ready.
  /// - Rejects duplicate listening requests if already listening.
  /// - Emits interim and final results through [onResultCallback] and class [onResult].
  /// - Returns `true` if listening started successfully.
  Future<bool> startListening({
    void Function(SpeechResult result)? onResultCallback,
    void Function(double soundLevel)? onSoundLevelChangeCallback,
    String? localeId,
    Duration? listenFor,
    Duration? pauseFor,
    bool partialResults = true,
  }) async {
    if (_state == SpeechServiceState.disposed) return false;
    if (_adapter.isListening || _state == SpeechServiceState.listening) {
      debugPrint('SpeechService: Already listening.');
      return true;
    }

    if (_state != SpeechServiceState.ready) {
      final ok = await initialize();
      if (!ok) return false;
    }

    // Determine locale to use
    String? effectiveLocale = _selectedLocaleId;
    if (localeId != null) {
      if (isLocaleSupported(localeId)) {
        effectiveLocale = localeId;
      } else {
        debugPrint('SpeechService: Requested locale "$localeId" unsupported, using fallback "$effectiveLocale".');
      }
    }

    _lastWords = '';
    _lastError = null;

    try {
      await _adapter.listen(
        onResult: (result) {
          if (_state == SpeechServiceState.disposed) return;
          _lastWords = result.words;
          onResultCallback?.call(result);
          onResult?.call(result);
        },
        localeId: effectiveLocale,
        listenFor: listenFor ?? const Duration(seconds: 30),
        pauseFor: pauseFor ?? defaultPauseFor,
        partialResults: partialResults,
        onSoundLevelChange: (level) {
          if (_state == SpeechServiceState.disposed) return;
          onSoundLevelChangeCallback?.call(level);
          onSoundLevelChange?.call(level);
        },
      );

      _setState(SpeechServiceState.listening);
      return true;
    } catch (e, stack) {
      debugPrint('SpeechService.startListening error: $e\n$stack');
      _setError(SpeechError(message: 'Failed to start speech recognition: $e'));
      return false;
    }
  }

  /// Stops an active listening session gracefully and processes final results.
  Future<void> stopListening() async {
    if (_state == SpeechServiceState.disposed) return;
    if (!_adapter.isListening && _state != SpeechServiceState.listening) return;

    _setState(SpeechServiceState.stopping);
    try {
      await _adapter.stop();
      _setState(SpeechServiceState.ready);
    } catch (e, stack) {
      debugPrint('SpeechService.stopListening error: $e\n$stack');
      _setError(SpeechError(message: 'Error stopping speech recognition: $e'));
    }
  }

  /// Cancels an active listening session immediately, discarding results.
  Future<void> cancelListening() async {
    if (_state == SpeechServiceState.disposed) return;
    try {
      await _adapter.cancel();
      _lastWords = '';
      _setState(SpeechServiceState.ready);
    } catch (e, stack) {
      debugPrint('SpeechService.cancelListening error: $e\n$stack');
      _setError(SpeechError(message: 'Error cancelling speech recognition: $e'));
    }
  }

  /// Releases resources and cleans up listeners.
  Future<void> dispose() async {
    if (_state == SpeechServiceState.disposed) return;
    _setState(SpeechServiceState.disposed);
    try {
      await _adapter.dispose();
    } catch (e) {
      debugPrint('SpeechService.dispose error: $e');
    }
    onStateChanged = null;
    onError = null;
    onResult = null;
    onSoundLevelChange = null;
  }
}
