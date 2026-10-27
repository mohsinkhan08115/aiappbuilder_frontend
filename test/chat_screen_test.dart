import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aiappbuilder/data/services/api_service.dart';
import 'package:aiappbuilder/data/services/preferences_service.dart';
import 'package:aiappbuilder/features/chat/view/chat_screen.dart';

class FakeApiService extends ApiService {
  String? mockResponse;
  String? mockConversationId;
  String? mockError;
  List<SourceCitation> mockSources;
  List<String> mockSearchQueries;
  Duration delay;
  int callCount = 0;
  String? lastMessage;
  String? lastConversationId;
  Completer<void>? pendingCompleter;

  FakeApiService({
    this.mockResponse = 'Mock AI response: Widget tree generated.',
    this.mockConversationId = 'conv-456',
    this.mockError,
    this.mockSources = const [],
    this.mockSearchQueries = const [],
    this.delay = Duration.zero,
  });

  @override
  Future<ChatResponse> sendChatMessage(
    String message, {
    String? conversationId,
    String? systemInstruction,
    CancelToken? cancelToken,
  }) async {
    callCount++;
    lastMessage = message;
    lastConversationId = conversationId;

    if (pendingCompleter != null) {
      await pendingCompleter!.future;
    } else if (delay > Duration.zero) {
      await Future.delayed(delay);
    }

    if (cancelToken != null && cancelToken.isCancelled) {
      throw 'Request was cancelled.';
    }

    if (mockError != null) {
      throw mockError!;
    }

    return ChatResponse(
      response: mockResponse ?? 'Default response',
      conversationId: mockConversationId ?? 'conv-default',
      sources: mockSources,
      searchQueries: mockSearchQueries,
    );
  }

  bool mockAuthenticated = false;
  List<Map<String, dynamic>> mockConversations = [];
  Map<String, dynamic> mockConversationDetail = {};
  String? deletedConversationId;

  @override
  bool get isAuthenticated => mockAuthenticated;

  @override
  Future<List<Map<String, dynamic>>> listConversations({
    int limit = 30,
    int offset = 0,
  }) async {
    return mockConversations;
  }

  @override
  Future<Map<String, dynamic>> getConversation(String conversationId) async {
    return mockConversationDetail;
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    deletedConversationId = conversationId;
  }
}

void main() {
  setUp(() => ChatSessionMemory.reset());

  group('ChatScreen Layout & Responsive Tests', () {
    Widget buildSubject({ApiService? apiService}) {
      return MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ChatScreen(
            onNavigate: (_) {},
            onOpenVoice: () {},
            onOpenWizard: () {},
            onNotify: (_) {},
            apiService: apiService,
          ),
        ),
      );
    }

    testWidgets(
      'renders properly on Desktop width (1280x900) without layout overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('AI CHAT'), findsOneWidget);
        expect(find.text('Build through conversation'), findsOneWidget);
        expect(find.text('Build a finance dashboard'), findsWidgets);
        expect(find.text('Open files'), findsWidgets);
        expect(find.text('Ask AI or describe a change…'), findsOneWidget);
        expect(find.text('GENERATION EVIDENCE'), findsOneWidget);
      },
    );

    testWidgets(
      'renders properly on Tablet width (768x1024) without unbounded height error',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(768, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('AI CHAT'), findsOneWidget);
        expect(find.text('Build through conversation'), findsOneWidget);
        expect(find.text('Ask AI or describe a change…'), findsOneWidget);
      },
    );

    testWidgets(
      'renders properly on Mobile width (375x812) without unbounded height or flex overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('AI CHAT'), findsOneWidget);
        expect(find.text('Build through conversation'), findsOneWidget);
        expect(find.text('Ask AI or describe a change…'), findsOneWidget);
        expect(find.text('GENERATION EVIDENCE'), findsOneWidget);
      },
    );

    testWidgets(
      'Recent Chats sidebar can be resized by dragging the divider with min/max bounds and saves to preferences',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        SharedPreferences.setMockInitialValues({});
        final prefs = await PreferencesService.create();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(body: ChatScreen(preferencesService: prefs)),
          ),
        );
        await tester.pumpAndSettle();

        final dividerFinder = find.byKey(
          const Key('chat_sidebar_resize_divider'),
        );
        expect(dividerFinder, findsOneWidget);

        // Initial sidebar width is default 260
        final sidebarFinder = find
            .ancestor(
              of: find.text('RECENT CHATS'),
              matching: find.byType(SizedBox),
            )
            .first;
        SizedBox sidebarBox = tester.widget<SizedBox>(sidebarFinder);
        expect(sidebarBox.width, 260.0);

        // Drag divider right by 60px -> width becomes 320.0
        await tester.drag(dividerFinder, const Offset(60, 0));
        await tester.pumpAndSettle();

        sidebarBox = tester.widget<SizedBox>(sidebarFinder);
        expect(sidebarBox.width, 320.0);
        expect(prefs.getChatSidebarWidth(), 320.0);

        // Drag divider left by 200px -> clamped to minChatSidebarWidth (180.0)
        await tester.drag(dividerFinder, const Offset(-200, 0));
        await tester.pumpAndSettle();

        sidebarBox = tester.widget<SizedBox>(sidebarFinder);
        expect(sidebarBox.width, 180.0);
        expect(prefs.getChatSidebarWidth(), 180.0);

        // Drag divider right by 500px -> clamped to maxChatSidebarWidth (420.0)
        await tester.drag(dividerFinder, const Offset(500, 0));
        await tester.pumpAndSettle();

        sidebarBox = tester.widget<SizedBox>(sidebarFinder);
        expect(sidebarBox.width, 420.0);
        expect(prefs.getChatSidebarWidth(), 420.0);
      },
    );

    testWidgets(
      'Project Linked Response panel can be resized by dragging the divider in both directions with min/max bounds and saves to preferences',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        SharedPreferences.setMockInitialValues({});
        final prefs = await PreferencesService.create();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(body: ChatScreen(preferencesService: prefs)),
          ),
        );
        await tester.pumpAndSettle();

        final dividerFinder = find.byKey(
          const Key('evidence_panel_resize_divider'),
        );
        expect(dividerFinder, findsOneWidget);

        // Find the Generation Evidence / Project Linked Response container
        final evidenceFinder = find
            .ancestor(
              of: find.text('GENERATION EVIDENCE'),
              matching: find.byType(Container),
            )
            .first;

        // Initial Project Linked Response height is default 180.0
        expect(tester.getSize(evidenceFinder).height, 180.0);
        expect(prefs.getEvidencePanelHeight(), 180.0);

        // Drag divider UP (negative dy) by 70px -> height increases to 250.0
        await tester.drag(dividerFinder, const Offset(0, -70));
        await tester.pumpAndSettle();

        expect(tester.getSize(evidenceFinder).height, 250.0);
        expect(prefs.getEvidencePanelHeight(), 250.0);

        // Drag divider DOWN (positive dy) by 200px -> clamped to minEvidencePanelHeight (110.0)
        await tester.drag(dividerFinder, const Offset(0, 200));
        await tester.pumpAndSettle();

        expect(tester.getSize(evidenceFinder).height, 110.0);
        expect(prefs.getEvidencePanelHeight(), 110.0);

        // Drag divider UP by 500px -> clamped to maxEvidencePanelHeight (420.0)
        await tester.drag(dividerFinder, const Offset(0, -500));
        await tester.pumpAndSettle();

        expect(tester.getSize(evidenceFinder).height, 420.0);
        expect(prefs.getEvidencePanelHeight(), 420.0);

        // Verify Recent Chats preference remains untouched and isolated
        expect(
          prefs.getChatSidebarWidth(),
          PreferencesService.defaultChatSidebarWidth,
        );
      },
    );

    testWidgets(
      'Project Linked Response divider adapts safely on smaller viewports and auto-expands on drag',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        SharedPreferences.setMockInitialValues({});
        final prefs = await PreferencesService.create();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(body: ChatScreen(preferencesService: prefs)),
          ),
        );
        await tester.pumpAndSettle();

        final dividerFinder = find.byKey(
          const Key('evidence_panel_resize_divider'),
        );
        final evidenceFinder = find
            .ancestor(
              of: find.text('GENERATION EVIDENCE'),
              matching: find.byType(Container),
            )
            .first;

        // Tap header to collapse
        await tester.tap(find.text('GENERATION EVIDENCE'));
        await tester.pumpAndSettle();

        // Collapsed height is header-only (less than min expanded panel height)
        final collapsedHeight = tester.getSize(evidenceFinder).height;
        expect(
          collapsedHeight < PreferencesService.minEvidencePanelHeight,
          isTrue,
        );

        // Dragging divider UP while collapsed auto-expands and applies height
        await tester.drag(dividerFinder, const Offset(0, -50));
        await tester.pumpAndSettle();

        // Verified expanded again and height increased safely
        final expandedHeight = tester.getSize(evidenceFinder).height;
        expect(
          expandedHeight >= PreferencesService.minEvidencePanelHeight,
          isTrue,
        );
        expect(expandedHeight > collapsedHeight, isTrue);
        expect(find.text('Open files'), findsWidgets);
      },
    );
  });

  group('ChatScreen Backend API Integration & Interaction Tests', () {
    Widget buildSubject({required ApiService apiService}) {
      return MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ChatScreen(
            onNavigate: (_) {},
            onOpenVoice: () {},
            onOpenWizard: () {},
            onNotify: (_) {},
            apiService: apiService,
          ),
        ),
      );
    }

    testWidgets(
      'Submitting message sends request to ApiService and renders response',
      (WidgetTester tester) async {
        final fakeApi = FakeApiService(
          mockResponse: 'Here is the Flutter code for dark mode.',
          mockConversationId: 'conv-test-99',
        );

        await tester.pumpWidget(buildSubject(apiService: fakeApi));
        await tester.pumpAndSettle();

        final inputField = find.byType(TextField);
        await tester.enterText(inputField, 'Add dark mode toggle');
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();

        expect(fakeApi.callCount, 1);
        expect(fakeApi.lastMessage, 'Add dark mode toggle');
        expect(find.text('Add dark mode toggle'), findsOneWidget);
        expect(
          find.text('Here is the Flutter code for dark mode.'),
          findsOneWidget,
        );
        expect(find.text('Send'), findsOneWidget);
      },
    );

    testWidgets(
      'Prevents duplicate submissions and displays Stop button while in-flight',
      (WidgetTester tester) async {
        final completer = Completer<void>();
        final fakeApi = FakeApiService();
        fakeApi.pendingCompleter = completer;

        await tester.pumpWidget(buildSubject(apiService: fakeApi));
        await tester.pumpAndSettle();

        final inputField = find.byType(TextField);
        await tester.enterText(inputField, 'First message');
        await tester.tap(find.text('Send'));
        await tester.pump();

        // In flight: Stop button visible, Send not visible
        expect(find.text('Stop'), findsOneWidget);
        expect(find.text('Send'), findsNothing);
        expect(fakeApi.callCount, 1);

        // Attempt second submission while loading
        await tester.tap(find.text('Stop'));
        await tester.pump();

        completer.complete();
        await tester.pumpAndSettle();

        // Finished: Send restored, callCount remained 1
        expect(find.text('Send'), findsOneWidget);
        expect(fakeApi.callCount, 1);
      },
    );

    testWidgets(
      'Handles network and backend errors gracefully with error badge',
      (WidgetTester tester) async {
        final fakeApi = FakeApiService(
          mockError: 'FastAPI validation error: Message cannot be empty.',
        );

        await tester.pumpWidget(buildSubject(apiService: fakeApi));
        await tester.pumpAndSettle();

        final inputField = find.byType(TextField);
        await tester.enterText(inputField, 'Cause error');
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();

        expect(fakeApi.callCount, 1);
        expect(
          find.text(
            'Failed to generate response: FastAPI validation error: Message cannot be empty.',
          ),
          findsOneWidget,
        );
        expect(find.text('Send'), findsOneWidget);
      },
    );

    testWidgets('New chat button creates a fresh thread', (
      WidgetTester tester,
    ) async {
      final fakeApi = FakeApiService();
      await tester.pumpWidget(buildSubject(apiService: fakeApi));
      await tester.pumpAndSettle();

      // Click "New chat"
      await tester.tap(find.text('New chat'));
      await tester.pumpAndSettle();

      expect(find.textContaining('New conversation'), findsWidgets);
      expect(
        find.text(
          'Hello! What Flutter or full-stack application would you like to plan or build?',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'Renders markdown code blocks with syntax block and Copy code button',
      (WidgetTester tester) async {
        final fakeApi = FakeApiService(
          mockResponse:
              'Here is the implementation:\n```dart\nvoid main() {\n  runApp(const MyApp());\n}\n```\nEnjoy coding!',
        );

        await tester.pumpWidget(buildSubject(apiService: fakeApi));
        await tester.pumpAndSettle();

        final inputField = find.byType(TextField);
        await tester.enterText(inputField, 'Show me main dart code');
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();

        expect(find.text('DART'), findsOneWidget);
        expect(find.text('Copy code'), findsOneWidget);
        expect(find.textContaining('runApp(const MyApp());'), findsOneWidget);
        expect(find.text('Enjoy coding!'), findsOneWidget);
      },
    );

    testWidgets('Clicking suggested prompt immediately submits it', (
      WidgetTester tester,
    ) async {
      final fakeApi = FakeApiService(
        mockResponse: 'Dashboard architecture generated.',
      );

      await tester.pumpWidget(buildSubject(apiService: fakeApi));
      await tester.pumpAndSettle();

      // Click "New chat" to see starter prompts
      await tester.tap(find.text('New chat'));
      await tester.pumpAndSettle();

      final promptText =
          'Build a modern finance dashboard with authentication and analytics.';
      final promptCard = find.text(promptText);
      expect(promptCard, findsWidgets);

      await tester.tap(promptCard.first);
      await tester.pumpAndSettle();

      expect(fakeApi.callCount, 1);
      expect(fakeApi.lastMessage, promptText);
      expect(find.text('Dashboard architecture generated.'), findsOneWidget);
    });

    testWidgets('Delete thread removes conversation from session memory', (
      WidgetTester tester,
    ) async {
      final fakeApi = FakeApiService();

      await tester.pumpWidget(buildSubject(apiService: fakeApi));
      await tester.pumpAndSettle();

      // Create new chat
      await tester.tap(find.text('New chat'));
      await tester.pumpAndSettle();

      final deleteBtn = find.byTooltip('Delete thread');
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Verify conversation cleared or deleted
      expect(find.text('Build a finance dashboard'), findsWidgets);
    });

    testWidgets(
      'ChatSessionMemory retains threads and messages across client screen re-navigation',
      (WidgetTester tester) async {
        final fakeApi = FakeApiService(
          mockResponse: 'Navigation test response preserved.',
        );

        // Step 1: Open chat screen and send a unique message
        await tester.pumpWidget(buildSubject(apiService: fakeApi));
        await tester.pumpAndSettle();

        final inputField = find.byType(TextField);
        await tester.enterText(inputField, 'Persistent across page switch');
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();

        expect(find.text('Persistent across page switch'), findsOneWidget);
        expect(
          find.text('Navigation test response preserved.'),
          findsOneWidget,
        );

        // Step 2: Navigate away (simulate opening Projects screen)
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('Projects Page'))),
        );
        await tester.pumpAndSettle();
        expect(find.text('Projects Page'), findsOneWidget);

        // Step 3: Navigate back to AI Chat
        await tester.pumpWidget(buildSubject(apiService: fakeApi));
        await tester.pumpAndSettle();

        // Verify conversation and message are retained in session memory
        expect(
          find.text('Persistent across page switch', skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.text('Navigation test response preserved.', skipOffstage: false),
          findsOneWidget,
        );
      },
    );

    testWidgets('Retry button resends prompt after failed request', (
      WidgetTester tester,
    ) async {
      final fakeApi = FakeApiService(mockError: 'Network connection refused.');

      await tester.pumpWidget(buildSubject(apiService: fakeApi));
      await tester.pumpAndSettle();

      final inputField = find.byType(TextField);
      await tester.enterText(inputField, 'Attempt generation');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      // Verifies failed state with error message and Retry button
      expect(
        find.text('Failed to generate response: Network connection refused.'),
        findsOneWidget,
      );
      final retryButton = find.text('Retry response');
      expect(retryButton, findsOneWidget);

      // Clear the error and trigger Retry
      fakeApi.mockError = null;
      fakeApi.mockResponse = 'Successfully recovered after retry.';
      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      // Verifies recovered response
      expect(find.text('Successfully recovered after retry.'), findsOneWidget);
    });

    testWidgets(
      'loads and renders persistent conversations from backend when authenticated',
      (WidgetTester tester) async {
        final fakeApi = FakeApiService();
        fakeApi.mockAuthenticated = true;
        fakeApi.mockConversations = [
          {
            'id': 'conv-backend-999',
            'title': 'My Persisted Project Plan',
            'message_count': 2,
            'last_message': 'Plan generated successfully',
            'updated_at': DateTime.now().toIso8601String(),
          },
        ];
        fakeApi.mockConversationDetail = {
          'id': 'conv-backend-999',
          'title': 'My Persisted Project Plan',
          'messages': [
            {
              'id': 'msg-1',
              'role': 'user',
              'content': 'How to configure push notifications?',
              'created_at': DateTime.now()
                  .subtract(const Duration(minutes: 5))
                  .toIso8601String(),
            },
            {
              'id': 'msg-2',
              'role': 'model',
              'content': 'Use Firebase Cloud Messaging (FCM) with Flutter.',
              'created_at': DateTime.now()
                  .subtract(const Duration(minutes: 4))
                  .toIso8601String(),
            },
          ],
        };

        await tester.pumpWidget(buildSubject(apiService: fakeApi));
        await tester.pumpAndSettle();

        // Verifies database sync badge
        expect(find.text('Cloud sync · Saved in database'), findsOneWidget);
        // Verifies loaded conversation title in sidebar and header
        expect(find.text('My Persisted Project Plan'), findsWidgets);

        // Tap on the conversation in sidebar to load messages
        await tester.tap(find.text('My Persisted Project Plan').first);
        await tester.pumpAndSettle();

        expect(
          find.text('How to configure push notifications?'),
          findsOneWidget,
        );
        expect(
          find.text('Use Firebase Cloud Messaging (FCM) with Flutter.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('deletes conversation from backend when authenticated', (
      WidgetTester tester,
    ) async {
      final fakeApi = FakeApiService();
      fakeApi.mockAuthenticated = true;
      fakeApi.mockConversations = [
        {
          'id': 'conv-to-delete',
          'title': 'Chat to Delete',
          'message_count': 1,
          'updated_at': DateTime.now().toIso8601String(),
        },
      ];

      await tester.pumpWidget(buildSubject(apiService: fakeApi));
      await tester.pumpAndSettle();

      expect(find.text('Chat to Delete'), findsWidgets);

      final deleteBtn = find.byTooltip('Delete thread');
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(fakeApi.deletedConversationId, 'conv-to-delete');
    });
  });

  group('Phase 3: Citation Parsing & Clickable Sources UI Tests', () {
    test('parses valid citations and search queries from JSON', () {
      final json = {
        'success': true,
        'response': 'Flutter 3.24 introduced GPU rendering enhancements.',
        'conversation_id': 'conv-grounded-1',
        'sources': [
          {
            'title': 'What is new in Flutter 3.24',
            'url': 'https://docs.flutter.dev/release/whats-new',
            'domain': 'docs.flutter.dev',
            'published_date': '2026-08-15',
            'source_type': 'web_search',
          },
          {
            'title': 'Open-Meteo Weather API',
            'url': 'https://api.open-meteo.com/v1/forecast',
            'domain': 'open-meteo.com',
            'published_date': null,
            'source_type': 'weather_api',
          },
        ],
        'search_queries': ['Flutter 3.24 release notes', 'Flutter GPU'],
      };

      final parsed = ChatResponse.fromJson(json);

      expect(parsed.success, isTrue);
      expect(
        parsed.response,
        'Flutter 3.24 introduced GPU rendering enhancements.',
      );
      expect(parsed.conversationId, 'conv-grounded-1');
      expect(parsed.sources, hasLength(2));
      expect(parsed.sources[0].title, 'What is new in Flutter 3.24');
      expect(
        parsed.sources[0].url,
        'https://docs.flutter.dev/release/whats-new',
      );
      expect(parsed.sources[0].domain, 'docs.flutter.dev');
      expect(parsed.sources[0].publishedDate, '2026-08-15');
      expect(parsed.sources[0].sourceType, 'web_search');

      expect(parsed.sources[1].title, 'Open-Meteo Weather API');
      expect(parsed.sources[1].domain, 'open-meteo.com');
      expect(parsed.sources[1].publishedDate, isNull);
      expect(parsed.sources[1].sourceType, 'weather_api');

      expect(
        parsed.searchQueries,
        equals(['Flutter 3.24 release notes', 'Flutter GPU']),
      );
    });

    test('handles missing, null, and empty source lists and search queries', () {
      final nullSourcesJson = {
        'success': true,
        'response': 'Standard answer.',
        'conversation_id': 'conv-null',
        'sources': null,
        'search_queries': null,
      };
      final emptySourcesJson = {
        'success': true,
        'response': 'Empty sources answer.',
        'conversation_id': 'conv-empty',
        'sources': <dynamic>[],
        'search_queries': <dynamic>[],
      };

      final parsedNull = ChatResponse.fromJson(nullSourcesJson);
      expect(parsedNull.sources, isEmpty);
      expect(parsedNull.searchQueries, isEmpty);
      expect(parsedNull.response, 'Standard answer.');
      expect(parsedNull.conversationId, 'conv-null');

      final parsedEmpty = ChatResponse.fromJson(emptySourcesJson);
      expect(parsedEmpty.sources, isEmpty);
      expect(parsedEmpty.searchQueries, isEmpty);
      expect(parsedEmpty.response, 'Empty sources answer.');
      expect(parsedEmpty.conversationId, 'conv-empty');
    });

    test('maintains compatibility with older responses without citation fields', () {
      final legacyChatJson = {
        'success': true,
        'response': 'Legacy backend response.',
        'conversation_id': 'conv-legacy-42',
      };
      final parsedChat = ChatResponse.fromJson(legacyChatJson);
      expect(parsedChat.success, isTrue);
      expect(parsedChat.response, 'Legacy backend response.');
      expect(parsedChat.conversationId, 'conv-legacy-42');
      expect(parsedChat.sources, isEmpty);
      expect(parsedChat.searchQueries, isEmpty);

      final legacyMessageJson = {
        'id': 'msg-legacy-1',
        'role': 'model',
        'content': 'Legacy history message.',
        'created_at': '2026-10-20T12:00:00Z',
      };
      final parsedMessage = ChatMessage.fromJson(legacyMessageJson);
      expect(parsedMessage.text, 'Legacy history message.');
      expect(parsedMessage.isUser, isFalse);
      expect(parsedMessage.sources, isEmpty);
      expect(parsedMessage.searchQueries, isEmpty);
    });

    testWidgets(
      'renders source titles, domains, and available dates without showing search queries as citations',
      (WidgetTester tester) async {
        final fakeApi = FakeApiService(
          mockResponse: 'Here are the latest Flutter updates.',
          mockConversationId: 'conv-sources-ui',
          mockSources: const [
            SourceCitation(
              title: 'Flutter Official Documentation',
              url: 'https://docs.flutter.dev',
              domain: 'docs.flutter.dev',
              publishedDate: '2026-10-15',
              sourceType: 'web_search',
            ),
            SourceCitation(
              title: 'Dart Language Guide',
              url: 'https://dart.dev/guides',
              domain: 'dart.dev',
              publishedDate: null,
              sourceType: 'web_search',
            ),
          ],
          mockSearchQueries: const ['hidden internal search query'],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(body: ChatScreen(apiService: fakeApi)),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Latest Flutter news');
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();

        expect(find.text('Sources'), findsOneWidget);
        expect(find.text('Flutter Official Documentation'), findsOneWidget);
        expect(find.text('docs.flutter.dev'), findsOneWidget);
        expect(find.text('2026-10-15'), findsOneWidget);

        expect(find.text('Dart Language Guide'), findsOneWidget);
        expect(find.text('dart.dev'), findsOneWidget);

        // Search queries must never be displayed as citations
        expect(find.text('hidden internal search query'), findsNothing);
      },
    );

    testWidgets(
      'tapping a valid citation URL launches the URL via url launcher',
      (WidgetTester tester) async {
        final launchedUris = <Uri>[];
        final fakeApi = FakeApiService(
          mockResponse: 'Check the official Flutter docs.',
          mockSources: const [
            SourceCitation(
              title: 'Flutter Release Notes',
              url: 'https://docs.flutter.dev/release',
              domain: 'docs.flutter.dev',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ChatScreen(
                apiService: fakeApi,
                onLaunchUrl: (uri) async {
                  launchedUris.add(uri);
                  return true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Show release notes');
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();

        final chip = find.byKey(const Key('citation_source_chip_0'));
        expect(chip, findsOneWidget);

        await tester.tap(chip);
        await tester.pumpAndSettle();

        expect(launchedUris, hasLength(1));
        expect(
          launchedUris.first.toString(),
          'https://docs.flutter.dev/release',
        );
      },
    );

    testWidgets(
      'rejects malformed URLs and unsupported schemes and handles launch failures gracefully',
      (WidgetTester tester) async {
        final launchedUris = <Uri>[];
        final notifications = <String>[];
        final fakeApi = FakeApiService(
          mockResponse: 'Testing URL validation.',
          mockSources: const [
            SourceCitation(
              title: 'Unsupported JS Scheme',
              url: 'javascript:alert(1)',
              domain: 'malicious.example',
            ),
            SourceCitation(
              title: 'Malformed Missing Host',
              url: 'https://',
            ),
            SourceCitation(
              title: 'Unsupported File Scheme',
              url: 'file:///etc/passwd',
            ),
            SourceCitation(
              title: 'Valid Link With Launch Error',
              url: 'https://example.com/article',
              domain: 'example.com',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ChatScreen(
                apiService: fakeApi,
                onNotify: notifications.add,
                onLaunchUrl: (uri) async {
                  launchedUris.add(uri);
                  throw Exception('Browser unavailable');
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Test links');
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();

        // Tap javascript: link -> rejected before launch
        await tester.tap(find.byKey(const Key('citation_source_chip_0')));
        await tester.pumpAndSettle();
        expect(launchedUris, isEmpty);
        expect(notifications.last, 'Invalid or unsupported source URL.');

        // Tap malformed https:// link -> rejected before launch
        await tester.tap(find.byKey(const Key('citation_source_chip_1')));
        await tester.pumpAndSettle();
        expect(launchedUris, isEmpty);

        // Tap file:/// link -> rejected before launch
        await tester.tap(find.byKey(const Key('citation_source_chip_2')));
        await tester.pumpAndSettle();
        expect(launchedUris, isEmpty);

        // Tap valid https link whose launcher throws -> handled gracefully without crashing
        await tester.tap(find.byKey(const Key('citation_source_chip_3')));
        await tester.pumpAndSettle();
        expect(launchedUris, hasLength(1));
        expect(notifications.last, 'Could not open source link.');
        expect(find.text('Testing URL validation.'), findsOneWidget);
      },
    );

    testWidgets(
      'responses with no sources show no empty Sources section and preserve voice button behavior',
      (WidgetTester tester) async {
        var voiceOpened = false;
        final fakeApi = FakeApiService(
          mockResponse: 'Response without any grounded sources.',
          mockSources: const [],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ChatScreen(
                apiService: fakeApi,
                onOpenVoice: () => voiceOpened = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Simple greeting');
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();

        expect(
          find.text('Response without any grounded sources.'),
          findsOneWidget,
        );
        expect(find.text('Sources'), findsNothing);

        // Verify existing voice trigger remains intact
        await tester.tap(find.text('Talk to AI'));
        await tester.pumpAndSettle();
        expect(voiceOpened, isTrue);
      },
    );
  });
}
