/// Supported languages for voice input, AI response instruction, and TTS playback.
enum VoiceLanguage {
  english,
  urdu,
  pashto,
  unknown;

  String get code {
    switch (this) {
      case VoiceLanguage.english:
        return 'en';
      case VoiceLanguage.urdu:
        return 'ur';
      case VoiceLanguage.pashto:
        return 'ps';
      case VoiceLanguage.unknown:
        return 'unknown';
    }
  }

  String get localeId {
    switch (this) {
      case VoiceLanguage.english:
        return 'en_US';
      case VoiceLanguage.urdu:
        return 'ur_PK';
      case VoiceLanguage.pashto:
        return 'ps_AF';
      case VoiceLanguage.unknown:
        return 'en_US';
    }
  }

  String get displayName {
    switch (this) {
      case VoiceLanguage.english:
        return 'English';
      case VoiceLanguage.urdu:
        return 'Urdu (اردو)';
      case VoiceLanguage.pashto:
        return 'Pashto (پښتو)';
      case VoiceLanguage.unknown:
        return 'Auto';
    }
  }

  static VoiceLanguage fromCode(String? code) {
    if (code == null) return VoiceLanguage.unknown;
    final normalized = code.toLowerCase().trim().replaceAll('_', '-');
    if (normalized.startsWith('ur')) return VoiceLanguage.urdu;
    if (normalized.startsWith('ps')) return VoiceLanguage.pashto;
    if (normalized.startsWith('en')) return VoiceLanguage.english;
    return VoiceLanguage.unknown;
  }
}

/// Normalized outcome of language detection.
class LanguageDetectionResult {
  final VoiceLanguage language;
  final double confidence;
  final String detectionSource;
  final bool isAmbiguous;
  final bool isMixed;

  const LanguageDetectionResult({
    required this.language,
    required this.confidence,
    required this.detectionSource,
    this.isAmbiguous = false,
    this.isMixed = false,
  });

  @override
  String toString() =>
      'LanguageDetectionResult(lang: ${language.code}, conf: $confidence, source: $detectionSource, ambiguous: $isAmbiguous, mixed: $isMixed)';
}

/// Service dedicated to detecting user language, constructing targeted AI system instructions,
/// and resolving engine-supported TTS locales for English, Urdu, and Pashto.
class VoiceLanguageService {
  // Unique Pashto characters (strictly not shared with Urdu or standard Arabic)
  static final RegExp _pashtoUniqueChars = RegExp(
    r'[\u069A\u0681\u0685\u0689\u0693\u0696\u06BC\u06CD\u06D0]',
  );

  // Common distinctive Pashto words (when unique characters are absent)
  static final List<String> _pashtoKeywords = [
    'پښتو',
    'دی',
    'شوی',
    'کوی',
    'نه',
    'سره',
    'یې',
    'مو',
    'زه',
    'ته',
    'دا',
    'موږ',
  ];

  // Unique Urdu characters (not shared with standard Pashto)
  static final RegExp _urduUniqueChars = RegExp(
    r'[\u0679\u0688\u0691\u06BA\u06D2\u06C1\u06BE]',
  );

  // Common distinctive Urdu words
  static final List<String> _urduKeywords = [
    'اردو',
    'کیا',
    'ہے',
    'ہیں',
    'تھا',
    'تھی',
    'تھے',
    'نہیں',
    'اور',
    'آپ',
    'میں',
    'ہم',
    'کو',
    'سے',
    'کا',
    'کی',
    'کے',
    'کریں',
  ];

  // Arabic / Persian / Urdu / Pashto script block including presentation forms
  static final RegExp _arabicScriptRegex = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
  );

  // Latin / English character block
  static final RegExp _latinScriptRegex = RegExp(r'[a-zA-Z]');

  /// Checks whether [text] should be displayed in Right-to-Left (RTL) direction
  /// based on Urdu, Pashto, or Arabic script content.
  static bool isRtlText(String text) {
    if (text.trim().isEmpty) return false;
    final rtlMatches = _arabicScriptRegex.allMatches(text).length;
    if (rtlMatches == 0) return false;
    final latinMatches = _latinScriptRegex.allMatches(text).length;
    return rtlMatches >= (latinMatches * 0.3) || rtlMatches > 2;
  }

  /// Detects the target language of the recognized speech.
  ///
  /// Signals priority:
  /// 1. [userSelection]: Explicit user selection in the UI (highest authority).
  /// 2. [engineLocale]: Actual speech recognition locale reported by the engine.
  /// 3. Script / Lexical analysis of [text].
  /// 4. Default fallback: [VoiceLanguage.english].
  LanguageDetectionResult detectLanguage({
    required String text,
    VoiceLanguage userSelection = VoiceLanguage.unknown,
    String? engineLocale,
  }) {
    // 1. Explicit user selection
    if (userSelection != VoiceLanguage.unknown) {
      return LanguageDetectionResult(
        language: userSelection,
        confidence: 1.0,
        detectionSource: 'user_selection',
      );
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const LanguageDetectionResult(
        language: VoiceLanguage.unknown,
        confidence: 0.0,
        detectionSource: 'empty_input',
        isAmbiguous: true,
      );
    }

    final arabicCharCount = _arabicScriptRegex.allMatches(trimmed).length;
    final latinCharCount = _latinScriptRegex.allMatches(trimmed).length;
    final isMixed = arabicCharCount > 0 && latinCharCount > 0;

    // 2. Lexical & Script Analysis
    if (arabicCharCount > 0) {
      // Check for Pashto unique characters
      if (_pashtoUniqueChars.hasMatch(trimmed)) {
        return LanguageDetectionResult(
          language: VoiceLanguage.pashto,
          confidence: 0.95,
          detectionSource: 'script_pashto_unique',
          isMixed: isMixed,
        );
      }

      // Check for Urdu unique characters
      if (_urduUniqueChars.hasMatch(trimmed)) {
        return LanguageDetectionResult(
          language: VoiceLanguage.urdu,
          confidence: 0.95,
          detectionSource: 'script_urdu_unique',
          isMixed: isMixed,
        );
      }

      // Check keywords
      final words = trimmed.split(RegExp(r'\s+'));
      int pashtoKeywordHits = 0;
      int urduKeywordHits = 0;

      for (final w in words) {
        if (_pashtoKeywords.contains(w)) pashtoKeywordHits++;
        if (_urduKeywords.contains(w)) urduKeywordHits++;
      }

      if (pashtoKeywordHits > urduKeywordHits) {
        return LanguageDetectionResult(
          language: VoiceLanguage.pashto,
          confidence: 0.85,
          detectionSource: 'lexical_pashto',
          isMixed: isMixed,
        );
      }

      if (urduKeywordHits > pashtoKeywordHits) {
        return LanguageDetectionResult(
          language: VoiceLanguage.urdu,
          confidence: 0.85,
          detectionSource: 'lexical_urdu',
          isMixed: isMixed,
        );
      }

      // Arabic script present, but ambiguous (e.g. short words like "سلام")
      // Check engine locale if available
      if (engineLocale != null) {
        final engineLang = VoiceLanguage.fromCode(engineLocale);
        if (engineLang == VoiceLanguage.urdu ||
            engineLang == VoiceLanguage.pashto) {
          return LanguageDetectionResult(
            language: engineLang,
            confidence: 0.75,
            detectionSource: 'engine_locale_with_arabic_script',
            isMixed: isMixed,
          );
        }
      }

      // Conservative fallback for ambiguous Arabic script:
      // Note: As instructed, do NOT infer Pashto solely because text is non-English.
      // Default ambiguous Arabic script to Urdu with explicit ambiguity flag.
      return LanguageDetectionResult(
        language: VoiceLanguage.urdu,
        confidence: 0.50,
        detectionSource: 'ambiguous_arabic_script_fallback',
        isAmbiguous: true,
        isMixed: isMixed,
      );
    }

    // 3. Latin / English Script
    if (latinCharCount > 0) {
      return LanguageDetectionResult(
        language: VoiceLanguage.english,
        confidence: 0.90,
        detectionSource: 'script_latin',
        isMixed: isMixed,
      );
    }

    // 4. Fallback when text has no letters (e.g. symbols, numbers)
    if (engineLocale != null) {
      final engineLang = VoiceLanguage.fromCode(engineLocale);
      if (engineLang != VoiceLanguage.unknown) {
        return LanguageDetectionResult(
          language: engineLang,
          confidence: 0.60,
          detectionSource: 'engine_locale_fallback',
          isAmbiguous: true,
        );
      }
    }

    return const LanguageDetectionResult(
      language: VoiceLanguage.english,
      confidence: 0.30,
      detectionSource: 'default_fallback',
      isAmbiguous: true,
    );
  }

  /// Builds a language-consistent system instruction for the existing chat endpoint.
  /// Instructs the AI provider to reply in the user's spoken language while keeping code
  /// syntax, symbols, and technical identifiers in standard English/code formatting.
  String? buildSystemInstruction(VoiceLanguage language) {
    switch (language) {
      case VoiceLanguage.urdu:
        return 'You are an expert AI software architect and Flutter assistant. '
            'The user is conversing in Urdu. Please respond in fluent, natural Urdu (اردو), '
            'while keeping code blocks, variable names, class names, file paths, and syntax in standard English format.';
      case VoiceLanguage.pashto:
        return 'You are an expert AI software architect and Flutter assistant. '
            'The user is conversing in Pashto. Please respond in fluent, natural Pashto (پښتو), '
            'while keeping code blocks, variable names, class names, file paths, and syntax in standard English format.';
      case VoiceLanguage.english:
        return 'You are an expert AI software architect and Flutter assistant. '
            'Respond helpfully and concisely in English.';
      case VoiceLanguage.unknown:
        return null;
    }
  }

  /// Resolves the TTS locale identifier to use if verified to be available on the host device.
  ///
  /// Returns `null` if the language is unsupported on the platform (e.g. Pashto without TTS voice data).
  String? resolveTtsLocale({
    required VoiceLanguage language,
    required bool Function(String locale) isLocaleSupported,
  }) {
    switch (language) {
      case VoiceLanguage.urdu:
        if (isLocaleSupported('ur-PK') || isLocaleSupported('ur')) {
          return 'ur-PK';
        }
        return null;
      case VoiceLanguage.pashto:
        if (isLocaleSupported('ps-AF') || isLocaleSupported('ps')) {
          return 'ps-AF';
        }
        // Pashto TTS is verified only when engine specifically reports support.
        return null;
      case VoiceLanguage.english:
        if (isLocaleSupported('en-US') || isLocaleSupported('en')) {
          return 'en-US';
        }
        return null;
      case VoiceLanguage.unknown:
        return isLocaleSupported('en-US') ? 'en-US' : null;
    }
  }
}
