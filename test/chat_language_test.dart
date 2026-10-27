import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aiappbuilder/data/services/api_service.dart';
import 'package:aiappbuilder/data/services/preferences_service.dart';
import 'package:aiappbuilder/data/services/voice_language_service.dart';
import 'package:aiappbuilder/features/chat/view/chat_screen.dart';

class CapturingFakeApiService extends ApiService {
  String? lastMessage;
  String? lastSystemInstruction;
  String? mockResponse;

  CapturingFakeApiService({this.mockResponse = 'Mock response'});

  @override
  bool get isAuthenticated => false;

  @override
  Future<ChatResponse> sendChatMessage(
    String message, {
    String? conversationId,
    String? systemInstruction,
    CancelToken? cancelToken,
  }) async {
    lastMessage = message;
    lastSystemInstruction = systemInstruction;
    return ChatResponse(
      response: mockResponse ?? 'AI response',
      conversationId: conversationId ?? 'conv-123',
    );
  }
}

Widget createChatLanguageTestWidget({
  required ApiService apiService,
  PreferencesService? preferencesService,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ChatScreen(
        apiService: apiService,
        preferencesService: preferencesService,
      ),
    ),
  );
}

void main() {
  group('Urdu and Pashto Script & RTL Detection Unit Tests', () {
    test('isRtlText correctly identifies English text as LTR', () {
      expect(VoiceLanguageService.isRtlText('Hello Flutter developer!'), isFalse);
      expect(VoiceLanguageService.isRtlText('Build an offline SQLite repository'), isFalse);
      expect(VoiceLanguageService.isRtlText(''), isFalse);
      expect(VoiceLanguageService.isRtlText('   '), isFalse);
    });

    test('isRtlText correctly identifies Urdu text as RTL', () {
      expect(VoiceLanguageService.isRtlText('یہ ایک اردو پیغام ہے'), isTrue);
      expect(VoiceLanguageService.isRtlText('کیا حال ہے؟'), isTrue);
      expect(VoiceLanguageService.isRtlText('فلٹر ایپ بلڈر میں نیا فیچر بنائیں'), isTrue);
      // Extended Urdu characters: ے, ں, ڑ, ڑھ, ٹ, ڈ
      expect(VoiceLanguageService.isRtlText('گاڑی، سڑک، پڑھائی، لڑکا'), isTrue);
    });

    test('isRtlText correctly identifies Pashto text as RTL', () {
      expect(VoiceLanguageService.isRtlText('دا یو پښتو پیغام دی'), isTrue);
      expect(VoiceLanguageService.isRtlText('ښه راغلاست ملګرو'), isTrue);
      // Extended Pashto characters: ښ, ږ, څ, ځ, ڼ, ۍ, ې
      expect(VoiceLanguageService.isRtlText('څنګه یاست؟ موږ پښتو ليکو'), isTrue);
    });

    test('isRtlText correctly handles mixed English-Urdu and English-Pashto inputs', () {
      expect(VoiceLanguageService.isRtlText('Flutter ایپ میں Authentication شامل کریں'), isTrue);
      expect(VoiceLanguageService.isRtlText('په Flutter پروژه کې نوی Widget جوړ کړه'), isTrue);
    });

    test('Preserves full Urdu and Pashto character strings intact in ChatMessage', () {
      const urduPrompt = 'براہ کرم فلٹر میں لاگ ان اسکرین ڈیزائن کریں جس میں ے، ں، ڑ، ٹ، ڈ شامل ہوں';
      const pashtoPrompt = 'مهرباني وکړئ د پښتو ژبې لپاره ښ، ږ، څ، ځ، ڼ او ۍ ملاتړ تایید کړئ';

      final urduMsg = ChatMessage(
        text: urduPrompt,
        isUser: true,
        timestamp: DateTime.now(),
      );
      final pashtoMsg = ChatMessage(
        text: pashtoPrompt,
        isUser: false,
        timestamp: DateTime.now(),
      );

      expect(urduMsg.text, equals(urduPrompt));
      expect(pashtoMsg.text, equals(pashtoPrompt));
      expect(urduMsg.text.contains('ے'), isTrue);
      expect(urduMsg.text.contains('ں'), isTrue);
      expect(pashtoMsg.text.contains('ښ'), isTrue);
      expect(pashtoMsg.text.contains('څ'), isTrue);
    });
  });

  group('ChatScreen Language Controls & Request Steer Integration Tests', () {
    late CapturingFakeApiService apiService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ChatSessionMemory.reset();
      apiService = CapturingFakeApiService();
    });

    testWidgets('ChatScreen displays Language selector defaulting to Auto',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createChatLanguageTestWidget(apiService: apiService));
      await tester.pumpAndSettle();

      expect(find.text('Auto'), findsOneWidget);
      expect(find.byIcon(Icons.translate), findsOneWidget);
    });

    testWidgets('Selecting Pashto displays Pashto limitations banner',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createChatLanguageTestWidget(apiService: apiService));
      await tester.pumpAndSettle();

      // Open language popup menu
      await tester.tap(find.text('Auto'));
      await tester.pumpAndSettle();

      expect(find.text('Auto-detect'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('اردو (Urdu)'), findsOneWidget);
      expect(find.text('پښتو (Pashto)'), findsOneWidget);

      // Select Pashto
      await tester.tap(find.text('پښتو (Pashto)'));
      await tester.pumpAndSettle();

      // Verify button now shows Pashto
      expect(find.text('پښتو'), findsOneWidget);

      // Verify Pashto limitation note banner is visible
      expect(
        find.textContaining('Pashto note: LLM training corpus for Pashto is smaller than Urdu/English'),
        findsOneWidget,
      );
    });

    testWidgets('Auto-detect recognizes typed Urdu and sends Urdu system instruction preserving prompt text',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createChatLanguageTestWidget(apiService: apiService));
      await tester.pumpAndSettle();

      const urduQuery = 'مجھے فلٹر کے لیے ایک نیا کاؤنٹر ایپ بنا دیں';

      // Type Urdu prompt into chat input
      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, urduQuery);
      await tester.pump();

      // Tap Send button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send'));
      await tester.pumpAndSettle();

      // Verify API was called with exact unmodified user prompt
      expect(apiService.lastMessage, equals(urduQuery));

      // Verify Urdu system instruction was attached
      expect(apiService.lastSystemInstruction, isNotNull);
      expect(apiService.lastSystemInstruction, contains('Urdu'));
      expect(apiService.lastSystemInstruction, contains('(اردو)'));
    });

    testWidgets('Explicitly selected Pashto language sends Pashto system instruction',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createChatLanguageTestWidget(apiService: apiService));
      await tester.pumpAndSettle();

      // Select Pashto from language selector
      await tester.tap(find.text('Auto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('پښتو (Pashto)'));
      await tester.pumpAndSettle();

      const pashtoQuery = 'په فلټر کې د ډیټابیس کارول څنګه دي؟';

      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, pashtoQuery);
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Send'));
      await tester.pumpAndSettle();

      // Verify prompt is preserved intact
      expect(apiService.lastMessage, equals(pashtoQuery));

      // Verify Pashto system instruction was sent
      expect(apiService.lastSystemInstruction, isNotNull);
      expect(apiService.lastSystemInstruction, contains('Pashto'));
      expect(apiService.lastSystemInstruction, contains('(پښتو)'));
    });

    testWidgets('RTL rendering is applied to Urdu responses while code blocks remain LTR',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mixedResponseService = CapturingFakeApiService(
        mockResponse: 'دا ستاسو د فلټر کوډ دی:\n```dart\nvoid main() {\n  runApp(const MyApp());\n}\n```\nمهرباني وکړئ ازموینه وکړئ.',
      );

      await tester.pumpWidget(createChatLanguageTestWidget(apiService: mixedResponseService));
      await tester.pumpAndSettle();

      // Send a query
      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'کوډ راکړئ');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send'));
      await tester.pumpAndSettle();

      // Verify user message is rendered in Directionality RTL
      final userDirectionality = find.ancestor(
        of: find.text('کوډ راکړئ'),
        matching: find.byType(Directionality),
      );
      expect(userDirectionality, findsWidgets);
      final userDirWidget = tester.widget<Directionality>(userDirectionality.first);
      expect(userDirWidget.textDirection, equals(TextDirection.rtl));

      // Verify code block contains 'Copy code' and is rendered
      expect(find.text('Copy code'), findsOneWidget);
      expect(find.textContaining('void main()'), findsOneWidget);

      // Verify code block is wrapped in Directionality LTR
      final codeDirectionality = find.ancestor(
        of: find.textContaining('void main()'),
        matching: find.byType(Directionality),
      );
      expect(codeDirectionality, findsWidgets);
      final codeDirWidget = tester.widget<Directionality>(codeDirectionality.first);
      expect(codeDirWidget.textDirection, equals(TextDirection.ltr));
    });
  });
}
