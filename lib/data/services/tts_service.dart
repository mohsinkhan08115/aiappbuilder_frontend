import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Operational and lifecycle state of the Text-to-Speech service.
enum TtsServiceState {
  uninitialized,
  initializing,
  ready,
  speaking,
  paused,
  error,
  disposed,
}

/// Gender classification strictly extracted from platform TTS metadata.
/// If the host engine does not report gender metadata, it remains [unknown].
enum TtsVoiceGender {
  unknown,
  male,
  female,
}

/// Structured representation of a TTS voice discovered from the platform engine.
class TtsVoice {
  final String name;
  final String locale;
  final TtsVoiceGender gender;
  final String? identifier;
  final String? quality;

  const TtsVoice({
    required this.name,
    required this.locale,
    this.gender = TtsVoiceGender.unknown,
    this.identifier,
    this.quality,
  });

  /// Safely constructs a [TtsVoice] from platform map representations.
  /// Strict rule: Gender is ONLY assigned when the engine explicitly specifies
  /// 'male' or 'female'. No assumptions or name-based heuristics are used.
  factory TtsVoice.fromMap(Map<dynamic, dynamic> map) {
    final name = map['name']?.toString() ?? '';
    final locale = map['locale']?.toString() ?? '';
    final identifier = map['identifier']?.toString();
    final quality = map['quality']?.toString();

    final rawGender = (map['gender'] ?? '').toString().toLowerCase().trim();
    final TtsVoiceGender gender;
    if (rawGender == 'male') {
      gender = TtsVoiceGender.male;
    } else if (rawGender == 'female') {
      gender = TtsVoiceGender.female;
    } else {
      gender = TtsVoiceGender.unknown;
    }

    return TtsVoice(
      name: name,
      locale: locale,
      gender: gender,
      identifier: identifier,
      quality: quality,
    );
  }

  Map<String, String> toMap() {
    final map = <String, String>{
      'name': name,
      'locale': locale,
    };
    if (identifier != null) {
      map['identifier'] = identifier!;
    }
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TtsVoice &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          locale == other.locale &&
          gender == other.gender &&
          identifier == other.identifier;

  @override
  int get hashCode => Object.hash(name, locale, gender, identifier);

  @override
  String toString() =>
      'TtsVoice(name: "$name", locale: "$locale", gender: $gender, identifier: $identifier)';
}

/// Normalized representation of TTS domain errors.
class TtsError {
  final String message;
  final String? code;

  const TtsError({
    required this.message,
    this.code,
  });

  @override
  String toString() => 'TtsError(code: "$code", message: "$message")';
}

/// Real-time progress data emitted while speech is synthesizing / playing.
class TtsProgress {
  final String text;
  final int start;
  final int end;
  final String word;

  const TtsProgress({
    required this.text,
    required this.start,
    required this.end,
    required this.word,
  });

  @override
  String toString() => 'TtsProgress(word: "$word", range: $start..$end)';
}

/// Abstract adapter seam isolating [TtsService] from native platform channels
/// and enabling 100% deterministic unit testing without audio hardware.
abstract class TtsAdapter {
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion);
  Future<dynamic> speak(String text);
  Future<dynamic> stop();
  Future<dynamic> pause();
  Future<dynamic> resume();
  Future<dynamic> setLanguage(String language);
  Future<dynamic> setSpeechRate(double rate);
  Future<dynamic> setVolume(double volume);
  Future<dynamic> setPitch(double pitch);
  Future<dynamic> setVoice(Map<String, String> voice);
  Future<dynamic> clearVoice();
  Future<dynamic> getLanguages();
  Future<dynamic> getVoices();
  Future<dynamic> isLanguageAvailable(String language);

  void setStartHandler(VoidCallback callback);
  void setCompletionHandler(VoidCallback callback);
  void setPauseHandler(VoidCallback callback);
  void setContinueHandler(VoidCallback callback);
  void setCancelHandler(VoidCallback callback);
  void setProgressHandler(
      void Function(String text, int start, int end, String word) callback);
  void setErrorHandler(void Function(dynamic message) handler);
}

/// Production adapter delegating directly to [FlutterTts].
class DefaultTtsAdapter implements TtsAdapter {
  final FlutterTts _tts;

  DefaultTtsAdapter([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) =>
      _tts.awaitSpeakCompletion(awaitCompletion);

  @override
  Future<dynamic> speak(String text) => _tts.speak(text);

  @override
  Future<dynamic> stop() => _tts.stop();

  @override
  Future<dynamic> pause() => _tts.pause();

  @override
  Future<dynamic> resume() async {
    // Note: flutter_tts does not provide a direct resume() channel invocation on all platforms.
    return null;
  }

  @override
  Future<dynamic> setLanguage(String language) => _tts.setLanguage(language);

  @override
  Future<dynamic> setSpeechRate(double rate) => _tts.setSpeechRate(rate);

  @override
  Future<dynamic> setVolume(double volume) => _tts.setVolume(volume);

  @override
  Future<dynamic> setPitch(double pitch) => _tts.setPitch(pitch);

  @override
  Future<dynamic> setVoice(Map<String, String> voice) => _tts.setVoice(voice);

  @override
  Future<dynamic> clearVoice() => _tts.clearVoice();

  @override
  Future<dynamic> getLanguages() => _tts.getLanguages;

  @override
  Future<dynamic> getVoices() => _tts.getVoices;

  @override
  Future<dynamic> isLanguageAvailable(String language) =>
      _tts.isLanguageAvailable(language);

  @override
  void setStartHandler(VoidCallback callback) => _tts.setStartHandler(callback);

  @override
  void setCompletionHandler(VoidCallback callback) =>
      _tts.setCompletionHandler(callback);

  @override
  void setPauseHandler(VoidCallback callback) => _tts.setPauseHandler(callback);

  @override
  void setContinueHandler(VoidCallback callback) =>
      _tts.setContinueHandler(callback);

  @override
  void setCancelHandler(VoidCallback callback) =>
      _tts.setCancelHandler(callback);

  @override
  void setProgressHandler(
          void Function(String text, int start, int end, String word) callback) =>
      _tts.setProgressHandler(callback);

  @override
  void setErrorHandler(void Function(dynamic message) handler) =>
      _tts.setErrorHandler(handler);
}

/// Reusable, robust Text-to-Speech service for AI App Builder.
///
/// Features:
/// - Full lifecycle management: initialization, speech playback, stop, pause, resume, disposal.
/// - Dynamic platform language and voice discovery with verified availability checks.
/// - Explicit support preparation for English (`en-US`), Urdu (`ur-PK`), and Pashto (`ps-AF`).
///   Strict rule: Pashto is NEVER promised or claimed without platform engine verification.
/// - Voice selection by name or engine identifier with zero gender guessing.
/// - Validated ranges for speech rate (0.0 - 1.0), volume (0.0 - 1.0), and pitch (0.5 - 2.0).
/// - Concurrency guardrails preventing overlapping or conflicting speech sessions.
/// - Clean reactive streams and callbacks for state, error, and progress monitoring.
class TtsService {
  final TtsAdapter _adapter;

  TtsServiceState _state = TtsServiceState.uninitialized;
  TtsError? _lastError;
  String _currentLanguage = 'en-US';
  TtsVoice? _selectedVoice;
  double _speechRate = 0.5;
  double _volume = 1.0;
  double _pitch = 1.0;

  List<String> _supportedLanguages = [];
  List<TtsVoice> _availableVoices = [];
  bool _isDisposed = false;

  final _stateController = StreamController<TtsServiceState>.broadcast();
  final _errorController = StreamController<TtsError>.broadcast();
  final _progressController = StreamController<TtsProgress>.broadcast();

  // Callbacks
  void Function(TtsServiceState state)? onStateChanged;
  void Function(TtsError error)? onError;
  void Function(TtsProgress progress)? onProgress;
  VoidCallback? onStart;
  VoidCallback? onCompletion;
  VoidCallback? onPause;
  VoidCallback? onContinue;
  VoidCallback? onCancel;

  TtsService({TtsAdapter? adapter})
      : _adapter = adapter ?? DefaultTtsAdapter();

  // Public Getters
  TtsServiceState get state => _state;
  bool get isSpeaking => _state == TtsServiceState.speaking;
  bool get isPaused => _state == TtsServiceState.paused;
  bool get isReady =>
      _state == TtsServiceState.ready ||
      _state == TtsServiceState.speaking ||
      _state == TtsServiceState.paused;
  bool get isInitialized => isReady;
  bool get isDisposed => _isDisposed;

  TtsError? get lastError => _lastError;
  String get currentLanguage => _currentLanguage;
  TtsVoice? get selectedVoice => _selectedVoice;
  double get speechRate => _speechRate;
  double get volume => _volume;
  double get pitch => _pitch;

  List<String> get supportedLanguages => List.unmodifiable(_supportedLanguages);
  List<TtsVoice> get availableVoices => List.unmodifiable(_availableVoices);

  Stream<TtsServiceState> get stateStream => _stateController.stream;
  Stream<TtsError> get errorStream => _errorController.stream;
  Stream<TtsProgress> get progressStream => _progressController.stream;

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('TtsService has been disposed and cannot be used.');
    }
  }

  void _setState(TtsServiceState newState) {
    if (_state == newState || _isDisposed) return;
    _state = newState;
    onStateChanged?.call(_state);
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  void _handleError(String message, {String? code}) {
    final error = TtsError(message: message, code: code);
    _lastError = error;
    onError?.call(error);
    if (!_errorController.isClosed) {
      _errorController.add(error);
    }
  }

  void _wireAdapterCallbacks() {
    _adapter.setStartHandler(() {
      _setState(TtsServiceState.speaking);
      onStart?.call();
    });

    _adapter.setCompletionHandler(() {
      _setState(TtsServiceState.ready);
      onCompletion?.call();
    });

    _adapter.setPauseHandler(() {
      _setState(TtsServiceState.paused);
      onPause?.call();
    });

    _adapter.setContinueHandler(() {
      _setState(TtsServiceState.speaking);
      onContinue?.call();
    });

    _adapter.setCancelHandler(() {
      _setState(TtsServiceState.ready);
      onCancel?.call();
    });

    _adapter.setProgressHandler((text, start, end, word) {
      final progress =
          TtsProgress(text: text, start: start, end: end, word: word);
      onProgress?.call(progress);
      if (!_progressController.isClosed) {
        _progressController.add(progress);
      }
    });

    _adapter.setErrorHandler((dynamic message) {
      _setState(TtsServiceState.error);
      _handleError(message?.toString() ?? 'Unknown TTS platform error',
          code: 'platform_error');
    });
  }

  /// Initializes the TTS engine, registers listeners, and discovers supported languages and voices.
  Future<bool> initialize() async {
    _checkDisposed();

    if (isReady) {
      if (_supportedLanguages.isEmpty) {
        await refreshDiscovery();
      }
      return true;
    }

    _setState(TtsServiceState.initializing);
    _lastError = null;

    try {
      _wireAdapterCallbacks();
      if (!kIsWeb) {
        await _adapter.awaitSpeakCompletion(true);
      } else {
        await _adapter.awaitSpeakCompletion(false);
      }

      // 1. Discover Languages
      await _discoverLanguages();

      // 2. Discover Voices
      await _discoverVoices();

      // 3. Establish initial language
      final initialLang = _findSupportedLocale('en-US') ??
          _findSupportedLocale('en') ??
          (_supportedLanguages.isNotEmpty ? _supportedLanguages.first : 'en-US');

      try {
        await _adapter.setLanguage(initialLang);
        _currentLanguage = initialLang;
      } catch (e) {
        debugPrint('TtsService: Warning setting initial language "$initialLang": $e');
      }

      // 4. Configure initial rates and volume
      try {
        await _adapter.setSpeechRate(_speechRate);
        await _adapter.setVolume(_volume);
        await _adapter.setPitch(_pitch);
      } catch (e) {
        debugPrint('TtsService: Warning applying initial speech settings: $e');
      }

      _setState(TtsServiceState.ready);
      return true;
    } catch (e) {
      _setState(TtsServiceState.error);
      _handleError('Failed to initialize TTS engine: $e',
          code: 'init_failed');
      return false;
    }
  }

  /// Re-queries the engine for supported languages and voices if previously empty.
  Future<void> refreshDiscovery() async {
    if (_isDisposed) return;
    try {
      await _discoverLanguages();
      await _discoverVoices();
    } catch (e) {
      debugPrint('TtsService: refreshDiscovery error: $e');
    }
  }

  Future<void> _discoverLanguages() async {
    try {
      final dynamic rawLanguages = await _adapter.getLanguages();
      if (rawLanguages is List) {
        _supportedLanguages = rawLanguages
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else {
        _supportedLanguages = [];
      }
    } catch (e) {
      debugPrint('TtsService: Error discovering languages: $e');
      _supportedLanguages = [];
    }
  }

  Future<void> _discoverVoices() async {
    try {
      final dynamic rawVoices = await _adapter.getVoices();
      if (rawVoices is List) {
        _availableVoices = rawVoices
            .whereType<Map>()
            .map((map) => TtsVoice.fromMap(map))
            .where((v) => v.name.isNotEmpty)
            .toList();
      } else {
        _availableVoices = [];
      }
    } catch (e) {
      debugPrint('TtsService: Error discovering voices: $e');
      _availableVoices = [];
    }
  }

  String? _findSupportedLocale(String languageCode) {
    final normalized =
        languageCode.replaceAll('_', '-').toLowerCase().trim();

    // 1. Exact match (case-insensitive)
    for (final lang in _supportedLanguages) {
      final normSupported =
          lang.replaceAll('_', '-').toLowerCase().trim();
      if (normSupported == normalized) return lang;
    }

    // 2. Prefix match (e.g. 'en' matches 'en-US' or 'en-GB')
    for (final lang in _supportedLanguages) {
      final normSupported =
          lang.replaceAll('_', '-').toLowerCase().trim();
      if (normSupported == normalized ||
          normSupported.startsWith('$normalized-')) {
        return lang;
      }
    }

    return null;
  }

  /// Returns true if [languageCode] (e.g. 'en-US', 'ur-PK', 'ps-AF') is supported by the engine.
  bool isLanguageSupported(String languageCode) {
    if (_findSupportedLocale(languageCode) != null) return true;
    // On web platforms (Chrome), if voice discovery has not yet populated (empty list),
    // allow a carefully scoped fallback attempt for standard English ('en', 'en-US')
    // so browser-native default speech synthesis is attempted rather than prematurely blocked.
    // Pashto and other non-standard languages are strictly NOT claimed without engine verification.
    if (kIsWeb && _supportedLanguages.isEmpty) {
      final normalized = languageCode.replaceAll('_', '-').toLowerCase().trim();
      if (normalized == 'en' || normalized.startsWith('en-')) {
        return true;
      }
    }
    return false;
  }

  /// Sets the TTS spoken language if verified to be available on the host device.
  /// If the language is not supported:
  /// - If [fallbackToDefault] is true, retains current language without claiming the requested language was set.
  /// - Emits a [TtsError] and returns false.
  Future<bool> setLanguage(String languageCode,
      {bool fallbackToDefault = false}) async {
    _checkDisposed();

    final matched = _findSupportedLocale(languageCode);
    if (matched == null) {
      // Scoped web fallback: if voice list hasn't finished populating in Chrome,
      // allow setting standard English locale directly on the browser engine.
      if (kIsWeb && _supportedLanguages.isEmpty) {
        final normalized =
            languageCode.replaceAll('_', '-').toLowerCase().trim();
        if (normalized == 'en' || normalized.startsWith('en-')) {
          try {
            await _adapter.setLanguage(languageCode);
            _currentLanguage = languageCode;
            return true;
          } catch (e) {
            debugPrint(
                'TtsService: Web fallback setLanguage error for "$languageCode": $e');
          }
        }
      }

      final message =
          'Language "$languageCode" is not supported by the device TTS engine.';
      debugPrint('TtsService: $message');
      _handleError(message, code: 'unsupported_language');

      if (fallbackToDefault && _currentLanguage.isNotEmpty) {
        debugPrint(
            'TtsService: Retaining active language "$_currentLanguage" as fallback.');
      }
      return false;
    }

    try {
      await _adapter.setLanguage(matched);
      _currentLanguage = matched;
      return true;
    } catch (e) {
      _handleError('Failed to apply language "$matched": $e',
          code: 'set_language_failed');
      return false;
    }
  }

  /// Returns all available voices belonging to the given locale (e.g. 'en-US').
  List<TtsVoice> getVoicesForLocale(String locale) {
    final normalized = locale.replaceAll('_', '-').toLowerCase().trim();
    return _availableVoices.where((v) {
      final voiceNorm = v.locale.replaceAll('_', '-').toLowerCase().trim();
      return voiceNorm == normalized || voiceNorm.startsWith('$normalized-');
    }).toList();
  }

  /// Returns voices filtered strictly by verified platform gender metadata.
  /// If gender metadata is absent from the engine, voices remain [TtsVoiceGender.unknown].
  List<TtsVoice> getVoicesForGender(TtsVoiceGender gender) {
    if (gender == TtsVoiceGender.unknown) {
      return List.unmodifiable(_availableVoices);
    }
    return _availableVoices.where((v) => v.gender == gender).toList();
  }

  /// Sets a specific voice explicitly verified against [_availableVoices].
  Future<bool> selectVoice(TtsVoice voice) async {
    _checkDisposed();

    final exists = _availableVoices.any(
      (v) => v.name == voice.name && (v.locale.isEmpty || voice.locale.isEmpty || v.locale == voice.locale),
    );

    if (!exists) {
      final message =
          'Voice "${voice.name}" is not available on this device.';
      _handleError(message, code: 'unavailable_voice');
      return false;
    }

    try {
      await _adapter.setVoice(voice.toMap());
      _selectedVoice = voice;
      return true;
    } catch (e) {
      _handleError('Failed to set voice "${voice.name}": $e',
          code: 'set_voice_failed');
      return false;
    }
  }

  /// Selects a voice by its platform voice name.
  Future<bool> selectVoiceByName(String voiceName) async {
    _checkDisposed();

    final matched = _availableVoices.cast<TtsVoice?>().firstWhere(
          (v) => v?.name.toLowerCase() == voiceName.toLowerCase(),
          orElse: () => null,
        );

    if (matched == null) {
      final message =
          'Voice "$voiceName" is not available on this device.';
      _handleError(message, code: 'unavailable_voice');
      return false;
    }

    return await selectVoice(matched);
  }

  /// Selects a voice by its engine identifier (iOS/macOS).
  Future<bool> selectVoiceByIdentifier(String identifier) async {
    _checkDisposed();

    final matched = _availableVoices.cast<TtsVoice?>().firstWhere(
          (v) =>
              v?.identifier != null &&
              v!.identifier!.toLowerCase() == identifier.toLowerCase(),
          orElse: () => null,
        );

    if (matched == null) {
      final message =
          'Voice with identifier "$identifier" is not available on this device.';
      _handleError(message, code: 'unavailable_voice');
      return false;
    }

    return await selectVoice(matched);
  }

  /// Clears custom voice selection and restores the engine default.
  Future<void> clearVoice() async {
    _checkDisposed();
    try {
      await _adapter.clearVoice();
      _selectedVoice = null;
    } catch (e) {
      _handleError('Failed to clear voice: $e', code: 'clear_voice_failed');
    }
  }

  /// Configures speech playback rate (0.0 slowest to 1.0 fastest).
  Future<void> setSpeechRate(double rate) async {
    _checkDisposed();
    if (rate < 0.0 || rate > 1.0) {
      throw ArgumentError.value(
        rate,
        'rate',
        'Speech rate must be between 0.0 (slowest) and 1.0 (fastest)',
      );
    }
    try {
      await _adapter.setSpeechRate(rate);
      _speechRate = rate;
    } catch (e) {
      _handleError('Failed to set speech rate: $e', code: 'set_rate_failed');
    }
  }

  /// Configures speech volume (0.0 silent to 1.0 maximum).
  Future<void> setVolume(double volume) async {
    _checkDisposed();
    if (volume < 0.0 || volume > 1.0) {
      throw ArgumentError.value(
        volume,
        'volume',
        'Volume must be between 0.0 (silent) and 1.0 (loudest)',
      );
    }
    try {
      await _adapter.setVolume(volume);
      _volume = volume;
    } catch (e) {
      _handleError('Failed to set volume: $e', code: 'set_volume_failed');
    }
  }

  /// Configures voice pitch (0.5 lowest to 2.0 highest, 1.0 default).
  Future<void> setPitch(double pitch) async {
    _checkDisposed();
    if (pitch < 0.5 || pitch > 2.0) {
      throw ArgumentError.value(
        pitch,
        'pitch',
        'Pitch must be between 0.5 and 2.0 (1.0 default)',
      );
    }
    try {
      await _adapter.setPitch(pitch);
      _pitch = pitch;
    } catch (e) {
      _handleError('Failed to set pitch: $e', code: 'set_pitch_failed');
    }
  }

  /// Speaks the provided [text].
  ///
  /// Concurrency and validation rules:
  /// - Rejects empty or whitespace-only text with a domain error and returns false.
  /// - Auto-initializes if called prior to explicit initialization.
  /// - If already speaking:
  ///   - If [interrupt] is false (default): rejects overlapping speech session and returns false.
  ///   - If [interrupt] is true: stops active speech before commencing the new utterance.
  Future<bool> speak(String text, {bool interrupt = false}) async {
    _checkDisposed();

    if (text.trim().isEmpty) {
      _handleError('Speech text cannot be empty or whitespace only.',
          code: 'empty_text');
      return false;
    }

    if (_state == TtsServiceState.uninitialized) {
      final success = await initialize();
      if (!success) {
        return false;
      }
    }

    if (_state == TtsServiceState.speaking) {
      if (!interrupt) {
        _handleError(
          'TTS is already speaking. Stop current speech before starting a new session or pass interrupt: true.',
          code: 'already_speaking',
        );
        return false;
      }
      await stop();
    }

    _setState(TtsServiceState.speaking);
    _lastError = null;

    try {
      await _adapter.speak(text);
      return true;
    } catch (e) {
      _setState(TtsServiceState.error);
      _handleError('Error synthesizing speech: $e', code: 'speak_failed');
      return false;
    }
  }

  /// Stops ongoing speech playback and restores state to [TtsServiceState.ready].
  Future<void> stop() async {
    if (_isDisposed) return;
    try {
      await _adapter.stop();
    } catch (e) {
      _handleError('Error stopping TTS: $e', code: 'stop_failed');
    } finally {
      if (!_isDisposed) {
        _setState(TtsServiceState.ready);
      }
    }
  }

  /// Pauses current speech playback if supported by the host platform engine.
  Future<bool> pause() async {
    _checkDisposed();
    if (_state != TtsServiceState.speaking) {
      return false;
    }

    try {
      await _adapter.pause();
      _setState(TtsServiceState.paused);
      return true;
    } catch (e) {
      _handleError('Failed to pause speech: $e', code: 'pause_failed');
      return false;
    }
  }

  /// Resumes paused speech playback if supported by the platform engine.
  Future<bool> resume() async {
    _checkDisposed();
    if (_state != TtsServiceState.paused) {
      return false;
    }

    try {
      await _adapter.resume();
      _setState(TtsServiceState.speaking);
      return true;
    } catch (e) {
      _handleError('Failed to resume speech: $e', code: 'resume_failed');
      return false;
    }
  }

  /// Safely halts all speech activity and disposes stream controllers.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _state = TtsServiceState.disposed;
    onStateChanged?.call(_state);
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }

    try {
      await _adapter.stop();
    } catch (_) {}

    await _stateController.close();
    await _errorController.close();
    await _progressController.close();
  }
}
