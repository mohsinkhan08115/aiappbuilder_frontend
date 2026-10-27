import 'package:flutter_test/flutter_test.dart';
import 'package:aiappbuilder/data/services/voice_language_service.dart';

void main() {
  late VoiceLanguageService service;

  setUp(() {
    service = VoiceLanguageService();
  });

  group('VoiceLanguage Enum & Mapping Tests', () {
    test('maps language codes to correct enum values', () {
      expect(VoiceLanguage.fromCode('en'), equals(VoiceLanguage.english));
      expect(VoiceLanguage.fromCode('en_US'), equals(VoiceLanguage.english));
      expect(VoiceLanguage.fromCode('en-GB'), equals(VoiceLanguage.english));
      expect(VoiceLanguage.fromCode('ur'), equals(VoiceLanguage.urdu));
      expect(VoiceLanguage.fromCode('ur_PK'), equals(VoiceLanguage.urdu));
      expect(VoiceLanguage.fromCode('ps'), equals(VoiceLanguage.pashto));
      expect(VoiceLanguage.fromCode('ps_AF'), equals(VoiceLanguage.pashto));
      expect(VoiceLanguage.fromCode('unknown'), equals(VoiceLanguage.unknown));
      expect(VoiceLanguage.fromCode(null), equals(VoiceLanguage.unknown));
      expect(VoiceLanguage.fromCode('es'), equals(VoiceLanguage.unknown));
    });

    test('exposes correct localeIds and display names', () {
      expect(VoiceLanguage.english.localeId, equals('en_US'));
      expect(VoiceLanguage.urdu.localeId, equals('ur_PK'));
      expect(VoiceLanguage.pashto.localeId, equals('ps_AF'));

      expect(VoiceLanguage.english.displayName, equals('English'));
      expect(VoiceLanguage.urdu.displayName, contains('Urdu'));
      expect(VoiceLanguage.pashto.displayName, contains('Pashto'));
    });
  });

  group('Language Detection - User Selection Authority', () {
    test('prioritizes explicit user selection over text content', () {
      // User explicitly picked Urdu, even though text is in English
      final resultUrdu = service.detectLanguage(
        text: 'Build a flutter app',
        userSelection: VoiceLanguage.urdu,
      );
      expect(resultUrdu.language, equals(VoiceLanguage.urdu));
      expect(resultUrdu.confidence, equals(1.0));
      expect(resultUrdu.detectionSource, equals('user_selection'));

      // User explicitly picked Pashto
      final resultPashto = service.detectLanguage(
        text: 'Hello world',
        userSelection: VoiceLanguage.pashto,
      );
      expect(resultPashto.language, equals(VoiceLanguage.pashto));
      expect(resultPashto.confidence, equals(1.0));

      // User explicitly picked English
      final resultEnglish = service.detectLanguage(
        text: 'ایک موبائل ایپ بنائیں',
        userSelection: VoiceLanguage.english,
      );
      expect(resultEnglish.language, equals(VoiceLanguage.english));
      expect(resultEnglish.confidence, equals(1.0));
    });
  });

  group('Language Detection - Script & Lexical Analysis', () {
    test('detects pure English Latin text with high confidence', () {
      final res = service.detectLanguage(
        text: 'Create a Flutter counter app with state management',
      );
      expect(res.language, equals(VoiceLanguage.english));
      expect(res.confidence, greaterThanOrEqualTo(0.9));
      expect(res.isMixed, isFalse);
    });

    test('detects Urdu using unique Urdu characters (ٹ، ڈ، ڑ، ں، ے)', () {
      final res = service.detectLanguage(
        text: 'ایک خوبصورت لاگ ان اسکرین بنائیں',
      );
      expect(res.language, equals(VoiceLanguage.urdu));
      expect(res.confidence, greaterThanOrEqualTo(0.9));
      expect(res.detectionSource, equals('script_urdu_unique'));
    });

    test('detects Pashto using unique Pashto characters (ښ، ځ، څ، ڼ، ۍ، ې)', () {
      final res = service.detectLanguage(
        text: 'پښتو ژبه کې یو اپلیکیشن جوړ کړئ',
      );
      expect(res.language, equals(VoiceLanguage.pashto));
      expect(res.confidence, greaterThanOrEqualTo(0.9));
      expect(res.detectionSource, equals('script_pashto_unique'));
    });

    test('detects Pashto via distinctive keywords when unique characters are absent', () {
      final res = service.detectLanguage(
        text: 'زه غواړم دا کار وکړم',
      );
      // 'زه' and 'دا' are distinctive Pashto keywords
      expect(res.language, equals(VoiceLanguage.pashto));
      expect(res.confidence, greaterThanOrEqualTo(0.8));
    });

    test('detects Urdu via distinctive keywords when unique characters are absent', () {
      final res = service.detectLanguage(
        text: 'کیا آپ میری مدد کر سکتے ہیں',
      );
      // 'کیا', 'آپ', 'ہیں' are distinctive Urdu keywords
      expect(res.language, equals(VoiceLanguage.urdu));
      expect(res.confidence, greaterThanOrEqualTo(0.8));
    });

    test('handles mixed-language input (e.g. English keywords in Urdu sentence)', () {
      final res = service.detectLanguage(
        text: 'Flutter پروجیکٹ میں StateManagement شامل کریں',
      );
      expect(res.language, equals(VoiceLanguage.urdu));
      expect(res.isMixed, isTrue);
    });

    test('handles mixed-language input in Pashto', () {
      final res = service.detectLanguage(
        text: 'Flutter ایپ جوړ کړئ او ډیزاین ښکلی کړئ',
      );
      expect(res.language, equals(VoiceLanguage.pashto));
      expect(res.isMixed, isTrue);
    });

    test('handles ambiguous Arabic script safely without assuming Pashto', () {
      // Short common word without distinctive Urdu or Pashto markers
      final res = service.detectLanguage(
        text: 'سلام',
      );
      // As instructed: Do not infer Pashto solely because text is non-English.
      // Must be marked ambiguous.
      expect(res.isAmbiguous, isTrue);
      expect(res.language, isNot(equals(VoiceLanguage.pashto)));
    });

    test('resolves ambiguous Arabic script using actual speech engine locale', () {
      final resWithUrduEngine = service.detectLanguage(
        text: 'سلام',
        engineLocale: 'ur_PK',
      );
      expect(resWithUrduEngine.language, equals(VoiceLanguage.urdu));
      expect(resWithUrduEngine.detectionSource, equals('engine_locale_with_arabic_script'));

      final resWithPashtoEngine = service.detectLanguage(
        text: 'سلام',
        engineLocale: 'ps_AF',
      );
      expect(resWithPashtoEngine.language, equals(VoiceLanguage.pashto));
      expect(resWithPashtoEngine.detectionSource, equals('engine_locale_with_arabic_script'));
    });

    test('handles empty and whitespace-only text gracefully', () {
      final resEmpty = service.detectLanguage(text: '');
      expect(resEmpty.language, equals(VoiceLanguage.unknown));
      expect(resEmpty.confidence, equals(0.0));

      final resWhitespace = service.detectLanguage(text: '   \t  \n ');
      expect(resWhitespace.language, equals(VoiceLanguage.unknown));
      expect(resWhitespace.confidence, equals(0.0));
    });
  });

  group('System Instruction Generation Tests', () {
    test('builds appropriate system instructions for each language', () {
      final urduInst = service.buildSystemInstruction(VoiceLanguage.urdu);
      expect(urduInst, contains('Urdu (اردو)'));
      expect(urduInst, contains('standard English'));

      final pashtoInst = service.buildSystemInstruction(VoiceLanguage.pashto);
      expect(pashtoInst, contains('Pashto (پښتو)'));
      expect(pashtoInst, contains('standard English'));

      final englishInst = service.buildSystemInstruction(VoiceLanguage.english);
      expect(englishInst, contains('English'));

      final unknownInst = service.buildSystemInstruction(VoiceLanguage.unknown);
      expect(unknownInst, isNull);
    });
  });

  group('TTS Locale Resolution Tests', () {
    test('resolves supported Urdu and English locales when verified by engine', () {
      bool mockEngineChecker(String loc) =>
          loc == 'en-US' || loc == 'ur-PK' || loc == 'ur';

      final resolvedEn = service.resolveTtsLocale(
        language: VoiceLanguage.english,
        isLocaleSupported: mockEngineChecker,
      );
      expect(resolvedEn, equals('en-US'));

      final resolvedUr = service.resolveTtsLocale(
        language: VoiceLanguage.urdu,
        isLocaleSupported: mockEngineChecker,
      );
      expect(resolvedUr, equals('ur-PK'));
    });

    test('returns null for Pashto when device TTS engine does not support it', () {
      // Typical mobile device where English and Urdu exist, but Pashto TTS is absent
      bool mockEngineChecker(String loc) => loc == 'en-US' || loc == 'ur-PK';

      final resolvedPs = service.resolveTtsLocale(
        language: VoiceLanguage.pashto,
        isLocaleSupported: mockEngineChecker,
      );

      // Must be null; never pretend Pashto audio can be spoken
      expect(resolvedPs, isNull);
    });

    test('resolves Pashto locale if device engine explicitly reports it', () {
      bool mockEngineCheckerWithPashto(String loc) =>
          loc == 'en-US' || loc == 'ps-AF' || loc == 'ps';

      final resolvedPs = service.resolveTtsLocale(
        language: VoiceLanguage.pashto,
        isLocaleSupported: mockEngineCheckerWithPashto,
      );

      expect(resolvedPs, equals('ps-AF'));
    });
  });
}
