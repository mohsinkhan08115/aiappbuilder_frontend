import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/status_pill.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/preferences_service.dart';
import '../../../data/services/voice_language_service.dart';
import '../../agents/view/agent_workspace_screen.dart'; // for AnimatedWorkingDots

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final String? planTitle;
  final List<String>? planSteps;
  final String? lastSentPrompt;
  final List<SourceCitation> sources;
  final List<String> searchQueries;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.planTitle,
    this.planSteps,
    this.lastSentPrompt,
    this.sources = const [],
    this.searchQueries = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> map) {
    final rawQueries = map['search_queries'] ?? map['searchQueries'];
    final searchQueries = <String>[];
    if (rawQueries is List) {
      for (final q in rawQueries) {
        if (q != null) {
          final trimmed = q.toString().trim();
          if (trimmed.isNotEmpty) {
            searchQueries.add(trimmed);
          }
        }
      }
    }

    return ChatMessage(
      text: (map['content'] as String?) ?? (map['response'] as String?) ?? '',
      isUser: map['role'] == 'user',
      timestamp:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      sources: SourceCitation.listFromJson(map['sources']),
      searchQueries: searchQueries,
    );
  }
}

class ChatThread {
  String title;
  String subtitle;
  String? conversationId;
  final List<ChatMessage> messages;

  ChatThread({
    required this.title,
    required this.subtitle,
    this.conversationId,
    required this.messages,
  });
}

class ChatSessionMemory {
  static List<ChatThread>? threads;
  static int selectedThread = 0;
  static String? pendingInitialPrompt;

  static void reset() {
    threads = null;
    selectedThread = 0;
    pendingInitialPrompt = null;
  }
}

class ChatScreen extends StatefulWidget {
  final ApiService? apiService;
  final PreferencesService? preferencesService;
  final void Function(String route)? onNavigate;
  final VoidCallback? onOpenVoice;
  final VoidCallback? onOpenWizard;
  final void Function(String message)? onNotify;
  final Future<bool> Function(Uri uri)? onLaunchUrl;
  final String? initialPrompt;

  const ChatScreen({
    super.key,
    this.apiService,
    this.preferencesService,
    this.onNavigate,
    this.onOpenVoice,
    this.onOpenWizard,
    this.onNotify,
    this.onLaunchUrl,
    this.initialPrompt,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  late int _selectedThread;
  late List<ChatThread> _threads;
  CancelToken? _cancelToken;
  bool _isEvidenceExpanded = true;
  double _recentChatsWidth = PreferencesService.defaultChatSidebarWidth;
  bool _isResizingSidebar = false;
  bool _isDividerHovered = false;
  double _evidenceHeight = PreferencesService.defaultEvidencePanelHeight;
  bool _isResizingEvidence = false;
  bool _isEvidenceDividerHovered = false;
  VoiceLanguage _chatLanguage = VoiceLanguage.unknown;
  bool _isInputRtl = false;

  void _handleInputDirection() {
    final text = _inputController.text;
    final isRtl = VoiceLanguageService.isRtlText(text) ||
        ((_chatLanguage == VoiceLanguage.urdu ||
                _chatLanguage == VoiceLanguage.pashto) &&
            text.trim().isNotEmpty);
    if (isRtl != _isInputRtl && mounted) {
      setState(() => _isInputRtl = isRtl);
    }
  }

  ApiService get _apiService {
    if (widget.apiService != null) return widget.apiService!;
    try {
      return context.read<ApiService>();
    } catch (_) {
      return ApiService();
    }
  }

  PreferencesService? get _preferencesService {
    if (widget.preferencesService != null) return widget.preferencesService;
    try {
      return context.read<PreferencesService?>();
    } catch (_) {
      return null;
    }
  }

  void _syncSessionMemory() {
    ChatSessionMemory.threads = _threads;
    ChatSessionMemory.selectedThread = _selectedThread;
  }

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_handleInputDirection);
    if (ChatSessionMemory.threads != null) {
      _threads = ChatSessionMemory.threads!;
      _selectedThread = ChatSessionMemory.selectedThread.clamp(
        0,
        _threads.length - 1,
      );
    } else {
      _threads = [
        ChatThread(
          title: 'Build a finance dashboard',
          subtitle: 'Active session',
          messages: [
            ChatMessage(
              text:
                  'Build a modern finance dashboard with authentication and spending analytics.',
              isUser: true,
              timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
            ),
            ChatMessage(
              text:
                  'I understand the direction.\n\nI’ll create a responsive TypeScript dashboard with secure authentication, transaction views, and accessible analytics.',
              isUser: false,
              timestamp: DateTime.now().subtract(const Duration(minutes: 11)),
              planTitle: 'Proposed plan',
              planSteps: [
                'Set up project structure and design tokens',
                'Build authentication and dashboard flows',
                'Run supported tests and review changes',
              ],
            ),
          ],
        ),
        ChatThread(
          title: 'Fix authentication error',
          subtitle: 'Session thread',
          messages: [
            ChatMessage(
              text: 'Fix JWT session expiry handling in auth_service.dart.',
              isUser: true,
              timestamp: DateTime.now().subtract(const Duration(hours: 1)),
            ),
            ChatMessage(
              text:
                  'Inspecting auth_service.dart: We should catch TokenExpiredException and trigger session renewal before rejecting the request.',
              isUser: false,
              timestamp: DateTime.now().subtract(const Duration(hours: 1)),
            ),
          ],
        ),
      ];
      _selectedThread = 0;
      _syncSessionMemory();
    }

    final promptToPrefill =
        widget.initialPrompt ?? ChatSessionMemory.pendingInitialPrompt;
    if (promptToPrefill != null && promptToPrefill.isNotEmpty) {
      _inputController.text = promptToPrefill;
      ChatSessionMemory.pendingInitialPrompt = null;
    }

    final initialSidebarWidth = widget.preferencesService
        ?.getChatSidebarWidth();
    if (initialSidebarWidth != null) {
      _recentChatsWidth = initialSidebarWidth;
    }

    final initialEvidenceHeight = widget.preferencesService
        ?.getEvidencePanelHeight();
    if (initialEvidenceHeight != null) {
      _evidenceHeight = initialEvidenceHeight;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      if (_apiService.isAuthenticated) {
        _loadBackendConversations();
      }
      try {
        final prefs = _preferencesService;
        if (prefs != null && mounted) {
          setState(() {
            _recentChatsWidth = prefs.getChatSidebarWidth();
            _evidenceHeight = prefs.getEvidencePanelHeight();
            _chatLanguage = VoiceLanguage.fromCode(prefs.getChatLanguage());
            _handleInputDirection();
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _loadBackendConversations() async {
    try {
      final convs = await _apiService.listConversations();
      if (convs.isNotEmpty && mounted) {
        final loadedThreads = <ChatThread>[];
        for (final c in convs) {
          final title = (c['title'] as String?) ?? 'Conversation';
          final cid = c['id'] as String?;
          loadedThreads.add(
            ChatThread(
              title: title,
              subtitle: 'Saved chat',
              conversationId: cid,
              messages: [],
            ),
          );
        }
        setState(() {
          _threads = loadedThreads;
          _selectedThread = 0;
          _syncSessionMemory();
        });
        if (loadedThreads.isNotEmpty &&
            loadedThreads[0].conversationId != null) {
          await _loadThreadMessages(0);
        }
      }
    } catch (_) {
      // Retain fallback session memory on network failure
    }
  }

  Future<void> _loadThreadMessages(int index) async {
    if (index < 0 || index >= _threads.length) return;
    final cid = _threads[index].conversationId;
    if (cid == null) return;
    try {
      final detail = await _apiService.getConversation(cid);
      final rawMsgs = detail['messages'] as List? ?? [];
      final parsed = rawMsgs.map((m) {
        final map = m as Map<String, dynamic>;
        return ChatMessage.fromJson(map);
      }).toList();
      if (mounted) {
        setState(() {
          _threads[index].messages.clear();
          _threads[index].messages.addAll(parsed);
          _syncSessionMemory();
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _syncSessionMemory();
    _inputController.removeListener(_handleInputDirection);
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _cancelToken?.cancel('Screen disposed');
    super.dispose();
  }

  Future<void> _send({String? retryText}) async {
    final text = retryText ?? _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (retryText == null) {
      _inputController.clear();
    }

    final thread = _threads[_selectedThread];

    // If starting a fresh thread, update thread title from the first prompt
    if (thread.title.startsWith('New conversation') ||
        thread.title.startsWith('New Chat')) {
      final generatedTitle = text.length > 28
          ? '${text.substring(0, 28)}…'
          : text;
      thread.title = generatedTitle;
    }

    if (retryText == null) {
      final userMsg = ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      );
      setState(() {
        thread.messages.add(userMsg);
        _isLoading = true;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    _scrollToBottom();
    _cancelToken = CancelToken();

    final voiceService = VoiceLanguageService();
    final detection = voiceService.detectLanguage(
      text: text,
      userSelection: _chatLanguage,
    );
    final systemInstruction =
        voiceService.buildSystemInstruction(detection.language);

    try {
      final res = await _apiService.sendChatMessage(
        text,
        conversationId: thread.conversationId,
        systemInstruction: systemInstruction,
        cancelToken: _cancelToken,
      );

      if (mounted) {
        setState(() {
          thread.conversationId = res.conversationId;
          thread.messages.add(
            ChatMessage(
              text: res.response,
              isUser: false,
              timestamp: DateTime.now(),
              sources: res.sources,
              searchQueries: res.searchQueries,
            ),
          );
          _isLoading = false;
        });
        widget.onNotify?.call('AI response received.');
        _syncSessionMemory();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceFirst(
          RegExp(r'^Exception:\s*'),
          '',
        );
        setState(() {
          _isLoading = false;
          thread.messages.add(
            ChatMessage(
              text: 'Failed to generate response: $errorMsg',
              isUser: false,
              timestamp: DateTime.now(),
              isError: true,
              lastSentPrompt: text,
            ),
          );
        });
        widget.onNotify?.call('Chat error: $errorMsg');
        _syncSessionMemory();
        _scrollToBottom();
      }
    } finally {
      _cancelToken = null;
    }
  }

  void _stop() {
    _cancelToken?.cancel('User stopped generation');
    setState(() => _isLoading = false);
    widget.onNotify?.call('Generation stopped.');
  }

  void _createNewChat() {
    setState(() {
      final newIndex = _threads.length + 1;
      _threads.insert(
        0,
        ChatThread(
          title: 'New conversation $newIndex',
          subtitle: 'Active session',
          messages: [
            ChatMessage(
              text:
                  'Hello! What Flutter or full-stack application would you like to plan or build?',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );
      _selectedThread = 0;
      _syncSessionMemory();
    });
    widget.onNotify?.call('A fresh conversation is ready.');
    _focusNode.requestFocus();
  }

  void _deleteThread(int index) async {
    final targetCid = (index >= 0 && index < _threads.length)
        ? _threads[index].conversationId
        : null;
    if (targetCid != null && _apiService.isAuthenticated) {
      try {
        await _apiService.deleteConversation(targetCid);
      } catch (_) {}
    }
    if (_threads.length <= 1) {
      setState(() {
        _threads[0] = ChatThread(
          title: 'New conversation',
          subtitle: 'Active session',
          messages: [
            ChatMessage(
              text:
                  'Hello! What Flutter or full-stack application would you like to plan or build?',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          ],
        );
        _selectedThread = 0;
        _syncSessionMemory();
      });
      widget.onNotify?.call('Conversation cleared.');
      return;
    }

    setState(() {
      _threads.removeAt(index);
      if (_selectedThread >= _threads.length) {
        _selectedThread = _threads.length - 1;
      }
      _syncSessionMemory();
    });
    widget.onNotify?.call('Conversation deleted.');
  }

  void _copyToClipboard(String content, String feedbackLabel) {
    Clipboard.setData(ClipboardData(text: content));
    widget.onNotify?.call(feedbackLabel);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(feedbackLabel),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openCitationUrl(SourceCitation source) async {
    final uri = SourceCitation.tryParseValidUri(source.url);
    if (uri == null) {
      const msg = 'Invalid or unsupported source URL.';
      widget.onNotify?.call(msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(msg),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final bool launched;
      if (widget.onLaunchUrl != null) {
        launched = await widget.onLaunchUrl!(uri);
      } else {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
      if (!launched) {
        const msg = 'Could not open source link.';
        widget.onNotify?.call(msg);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(msg),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      const msg = 'Could not open source link.';
      widget.onNotify?.call(msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(msg),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 650;
        final isShortViewport = constraints.maxHeight < 620;

        // Ensure chat workspace preserves minimum usable space of ~220px
        final maxAllowedEvidenceHeight = (constraints.maxHeight - 305.0).clamp(
          PreferencesService.minEvidencePanelHeight,
          PreferencesService.maxEvidencePanelHeight,
        );
        final actualEvidenceHeight = _evidenceHeight.clamp(
          PreferencesService.minEvidencePanelHeight,
          maxAllowedEvidenceHeight,
        );

        return Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 10 : 16,
            isShortViewport ? 6 : 10,
            isCompact ? 10 : 16,
            isShortViewport ? 6 : 10,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Page Header with responsive actions
                  _buildPageHeader(
                    isDark,
                    isCompact: isCompact,
                    isShortViewport: isShortViewport,
                  ),
                  SizedBox(height: isShortViewport ? 6 : 10),

                  // Chat Workspace Container (Recent chats rail + Resizable divider + Chat panel)
                  // Fills available viewport height without scrolling the outer page
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: LayoutBuilder(
                        builder: (context, chatConstraints) {
                          final isWide = chatConstraints.maxWidth > 750;
                          if (!isWide) {
                            return _buildChatPanel(isDark, isWide: false);
                          }

                          // Ensure chat panel always retains at least 320px
                          final maxAllowed = (chatConstraints.maxWidth - 320.0)
                              .clamp(
                                PreferencesService.minChatSidebarWidth,
                                PreferencesService.maxChatSidebarWidth,
                              );
                          final actualWidth = _recentChatsWidth.clamp(
                            PreferencesService.minChatSidebarWidth,
                            maxAllowed,
                          );

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: actualWidth,
                                child: _buildConversationList(isDark),
                              ),
                              _buildResizeDivider(isDark, maxAllowed),
                              Expanded(
                                child: _buildChatPanel(isDark, isWide: true),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  // Draggable Divider between Chat Workspace and Project Linked Response
                  _buildEvidenceResizeDivider(isDark, maxAllowedEvidenceHeight),

                  // Engineering Extension: Generation Evidence / Project-linked response (Docked at bottom, collapsible & resizable)
                  _buildGenerationEvidence(
                    isDark,
                    actualEvidenceHeight: actualEvidenceHeight,
                    isShortViewport: isShortViewport,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEvidenceResizeDivider(bool isDark, double maxAllowedHeight) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _isEvidenceDividerHovered = true),
      onExit: (_) => setState(() => _isEvidenceDividerHovered = false),
      child: GestureDetector(
        key: const Key('evidence_panel_resize_divider'),
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) {
          setState(() {
            _isResizingEvidence = true;
            if (!_isEvidenceExpanded) {
              _isEvidenceExpanded = true;
            }
          });
        },
        onVerticalDragUpdate: (details) {
          setState(() {
            // Dragging up (negative dy) increases bottom panel height; dragging down (positive dy) decreases it
            final nextHeight = _evidenceHeight - details.delta.dy;
            _evidenceHeight = nextHeight.clamp(
              PreferencesService.minEvidencePanelHeight,
              maxAllowedHeight,
            );
          });
        },
        onVerticalDragEnd: (_) {
          setState(() => _isResizingEvidence = false);
          _preferencesService?.setEvidencePanelHeight(_evidenceHeight);
        },
        onVerticalDragCancel: () {
          setState(() => _isResizingEvidence = false);
        },
        child: Container(
          height: 10,
          color: Colors.transparent,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: (_isEvidenceDividerHovered || _isResizingEvidence)
                  ? 3
                  : 1,
              decoration: BoxDecoration(
                color: (_isEvidenceDividerHovered || _isResizingEvidence)
                    ? AppColors.primaryBright
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResizeDivider(bool isDark, double maxAllowedWidth) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isDividerHovered = true),
      onExit: (_) => setState(() => _isDividerHovered = false),
      child: GestureDetector(
        key: const Key('chat_sidebar_resize_divider'),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          setState(() => _isResizingSidebar = true);
        },
        onHorizontalDragUpdate: (details) {
          setState(() {
            final nextWidth = _recentChatsWidth + details.delta.dx;
            _recentChatsWidth = nextWidth.clamp(
              PreferencesService.minChatSidebarWidth,
              maxAllowedWidth,
            );
          });
        },
        onHorizontalDragEnd: (_) {
          setState(() => _isResizingSidebar = false);
          _preferencesService?.setChatSidebarWidth(_recentChatsWidth);
        },
        onHorizontalDragCancel: () {
          setState(() => _isResizingSidebar = false);
        },
        child: Container(
          width: 8,
          color: Colors.transparent,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: (_isDividerHovered || _isResizingSidebar) ? 3 : 1,
              decoration: BoxDecoration(
                color: (_isDividerHovered || _isResizingSidebar)
                    ? AppColors.primaryBright
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader(
    bool isDark, {
    required bool isCompact,
    required bool isShortViewport,
  }) {
    final titleSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'AI CHAT',
          style: TextStyle(
            color: AppColors.cyan,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        SizedBox(height: isShortViewport ? 2 : 4),
        Text(
          'Build through conversation',
          style: TextStyle(
            fontSize: isCompact ? 18 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (!isShortViewport) ...[
          const SizedBox(height: 1),
          Text(
            'Plan, create, and refine software with project-aware assistance.',
            style: TextStyle(
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );

    final actionButtons = Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        OutlinedButton.icon(
          onPressed: widget.onOpenVoice,
          icon: const Icon(Icons.mic_none, size: 14),
          label: const Text('Talk to AI'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 30),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _createNewChat,
          icon: const Icon(Icons.add, size: 14),
          label: const Text('New chat'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 30),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );

    return isCompact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [titleSection, const SizedBox(height: 6), actionButtons],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: titleSection),
              actionButtons,
            ],
          );
  }

  Widget _buildGenerationEvidence(
    bool isDark, {
    required double actualEvidenceHeight,
    required bool isShortViewport,
  }) {
    return Container(
      height: _isEvidenceExpanded ? actualEvidenceHeight : null,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: _isEvidenceExpanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          InkWell(
            onTap: () =>
                setState(() => _isEvidenceExpanded = !_isEvidenceExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'GENERATION EVIDENCE',
                          style: TextStyle(
                            color: Color(0xFF9B91FF),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Project-linked response',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const StatusPill(
                        label: 'Complete',
                        type: StatusType.success,
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _isEvidenceExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 16,
                        color: isDark
                            ? AppColors.darkMuted
                            : AppColors.lightMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isEvidenceExpanded) ...[
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface2
                            : AppColors.lightSurface2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: const SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SelectableText(
                          "Future<Session?> restoreSession() async {\n  final token = await storage.read(key: 'session_token');\n  return token == null ? null : Session.fromToken(token);\n}",
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              widget.onNavigate?.call('Code & Files'),
                          icon: const Icon(Icons.code, size: 14),
                          label: const Text('Open files'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 28),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              widget.onNavigate?.call('Agent Workspace'),
                          icon: const Icon(Icons.psychology, size: 14),
                          label: const Text('View generating task'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 28),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConversationList(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkSidebar : AppColors.lightSidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar Header: Label + New Chat Action
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'RECENT CHATS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.cyan,
                      letterSpacing: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _createNewChat,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: 12,
                          color: AppColors.primaryBright,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'New',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBright,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Honest session scope notice
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 14, bottom: 8),
            child: Text(
              _apiService.isAuthenticated
                  ? 'Cloud sync · Saved in database'
                  : 'Session storage · Stored in active memory',
              style: TextStyle(
                fontSize: 9,
                color: isDark ? AppColors.darkMuted2 : AppColors.lightMuted2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const Divider(height: 1),

          // Thread List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: _threads.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final selected = _selectedThread == i;
                final thread = _threads[i];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedThread = i;
                      _syncSessionMemory();
                    });
                    if (_threads[i].conversationId != null &&
                        _threads[i].messages.isEmpty) {
                      _loadThreadMessages(i);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? (isDark
                                ? AppColors.darkSurface3
                                : AppColors.lightSurface3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: selected
                          ? const Border(
                              left: BorderSide(
                                color: AppColors.cyan,
                                width: 2.5,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                thread.title,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: selected
                                      ? (isDark
                                            ? AppColors.darkText
                                            : AppColors.lightText)
                                      : (isDark
                                            ? AppColors.darkMuted
                                            : AppColors.lightMuted),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${thread.messages.length} messages · ${thread.subtitle}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isDark
                                      ? AppColors.darkMuted2
                                      : AppColors.lightMuted2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selected)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 14),
                            onPressed: () => _deleteThread(i),
                            tooltip: 'Delete thread',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: isDark
                                ? AppColors.darkMuted
                                : AppColors.lightMuted,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel(bool isDark, {required bool isWide}) {
    final currentThread = _threads[_selectedThread];
    final hasMessages = currentThread.messages.isNotEmpty;

    return Column(
      children: [
        // Thread Context Header
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentThread.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons on top-right
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isWide) ...[
                    PopupMenuButton<int>(
                      tooltip: 'Switch conversation',
                      onSelected: (idx) => setState(() {
                        _selectedThread = idx;
                        _syncSessionMemory();
                      }),
                      color: isDark
                          ? AppColors.darkSurface2
                          : AppColors.lightSurface,
                      itemBuilder: (context) =>
                          List.generate(_threads.length, (i) {
                            return PopupMenuItem<int>(
                              value: i,
                              child: Text(
                                _threads[i].title,
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 12,
                              color: AppColors.darkMuted,
                            ),
                            SizedBox(width: 4),
                            Text('Chats', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _buildLanguageSelector(isDark, isCompact: !isWide),
                  const SizedBox(width: 8),
                  if (isWide)
                    OutlinedButton.icon(
                      onPressed: () => widget.onNavigate?.call('Code & Files'),
                      icon: const Icon(Icons.code, size: 13),
                      label: const Text('Open files'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                    )
                  else
                    IconButton(
                      tooltip: 'Open files',
                      onPressed: () => widget.onNavigate?.call('Code & Files'),
                      icon: const Icon(Icons.code, size: 14),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),

        // Scrollable Messages View or Empty State Prompts
        Expanded(
          child: hasMessages
              ? ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    for (final msg in currentThread.messages) ...[
                      if (msg.isUser)
                        _buildUserBubble(msg, isDark)
                      else
                        _buildAssistantBubble(msg, isDark),
                      const SizedBox(height: 20),
                    ],

                    if (currentThread.messages.length <= 1 && !_isLoading) ...[
                      const SizedBox(height: 8),
                      _buildStarterPromptCards(isDark),
                      const SizedBox(height: 20),
                    ],

                    // Live Thinking / Working animation state
                    if (_isLoading) ...[_buildThinkingIndicator(isDark)],
                  ],
                )
              : _buildEmptyConversationState(isDark),
        ),

        // Message Composer bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_chatLanguage == VoiceLanguage.pashto)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.cyan.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 12, color: AppColors.cyan),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Pashto note: LLM training corpus for Pashto is smaller than Urdu/English. Technical terms, syntax, and code will remain in English.',
                          style: TextStyle(fontSize: 10, color: AppColors.cyan),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      focusNode: _focusNode,
                      enabled: !_isLoading,
                      textDirection:
                          _isInputRtl ? TextDirection.rtl : TextDirection.ltr,
                      maxLines: 4,
                      minLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        height: _isInputRtl ? 1.6 : 1.4,
                        fontFamilyFallback: const [
                          'Noto Nastaliq Urdu',
                          'Noto Sans Arabic',
                          'Arial',
                        ],
                      ),
                      decoration: InputDecoration(
                        hintText: _chatLanguage == VoiceLanguage.urdu
                            ? 'یہاں سوال لکھیں یا تبدیلی بیان کریں…'
                            : _chatLanguage == VoiceLanguage.pashto
                                ? 'دلته پوښتنه ولیکئ یا بدلون بیان کړئ…'
                                : 'Ask AI or describe a change…',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (_) {
                        if (!_isLoading) _send();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isLoading)
                    ElevatedButton.icon(
                      onPressed: _stop,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.red.withValues(alpha: 0.2),
                        foregroundColor: AppColors.red,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.stop, size: 14),
                      label: const Text('Stop'),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => _send(),
                      style: ElevatedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.send, size: 14),
                      label: const Text('Send'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector(bool isDark, {bool isCompact = false}) {
    return PopupMenuButton<VoiceLanguage>(
      tooltip: 'Select AI response language',
      initialValue: _chatLanguage,
      onSelected: (VoiceLanguage lang) {
        setState(() {
          _chatLanguage = lang;
          _handleInputDirection();
        });
        _preferencesService?.setChatLanguage(lang.code);
        widget.onNotify?.call('Chat language set to ${lang.displayName}');
      },
      color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface,
      itemBuilder: (context) => [
        const PopupMenuItem<VoiceLanguage>(
          value: VoiceLanguage.unknown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 14, color: AppColors.primaryBright),
              SizedBox(width: 8),
              Text('Auto-detect', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuItem<VoiceLanguage>(
          value: VoiceLanguage.english,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language, size: 14, color: AppColors.darkMuted),
              SizedBox(width: 8),
              Text('English', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuItem<VoiceLanguage>(
          value: VoiceLanguage.urdu,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.format_textdirection_r_to_l, size: 14, color: Color(0xFF9B91FF)),
              SizedBox(width: 8),
              Text('اردو (Urdu)', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuItem<VoiceLanguage>(
          value: VoiceLanguage.pashto,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.format_textdirection_r_to_l, size: 14, color: AppColors.cyan),
              SizedBox(width: 8),
              Text('پښتو (Pashto)', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 6 : 10,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.translate, size: 13, color: AppColors.primaryBright),
            if (!isCompact) ...[
              const SizedBox(width: 6),
              Text(
                _chatLanguage == VoiceLanguage.unknown
                    ? 'Auto'
                    : _chatLanguage == VoiceLanguage.urdu
                        ? 'اردو'
                        : _chatLanguage == VoiceLanguage.pashto
                            ? 'پښتو'
                            : 'English',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 14, color: AppColors.darkMuted),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStarterPromptCards(bool isDark) {
    final suggestions = [
      'Build a modern finance dashboard with authentication and analytics.',
      'Fix JWT session expiry handling and token renewals.',
      'Generate an SQLite offline repository for domain models.',
      'Add adaptive layouts with responsive navigation for Flutter Web.',
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUGGESTED PROMPTS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: suggestions.map((prompt) {
              return InkWell(
                onTap: () {
                  _inputController.text = prompt;
                  _send();
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface2
                        : AppColors.lightSurface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, size: 14, color: AppColors.cyan),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          prompt,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyConversationState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                gradient: AppColors.titleGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'How can I help you build today?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Ask a question, describe a screen, or select a starter prompt below.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              ),
            ),
            const SizedBox(height: 24),
            _buildStarterPromptCards(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBubble(ChatMessage msg, bool isDark) {
    final isRtl = VoiceLanguageService.isRtlText(msg.text);
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 720),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface3 : AppColors.lightSurface3,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(3),
              ),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Directionality(
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: SelectableText(
                msg.text,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                style: TextStyle(
                  fontSize: 13,
                  height: isRtl ? 1.75 : 1.5,
                  fontFamilyFallback: const [
                    'Noto Nastaliq Urdu',
                    'Noto Sans Arabic',
                    'Arial',
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTimestamp(msg.timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppColors.darkMuted2 : AppColors.lightMuted2,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () =>
                    _copyToClipboard(msg.text, 'Prompt copied to clipboard'),
                child: Icon(
                  Icons.copy_rounded,
                  size: 12,
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(ChatMessage msg, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: msg.isError
                ? AppColors.red.withValues(alpha: 0.16)
                : AppColors.primary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            msg.isError ? Icons.error_outline : Icons.auto_awesome,
            color: msg.isError ? AppColors.red : const Color(0xFF9B91FF),
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Formatted Message Renderer (Code blocks + prose)
              _FormattedMessageView(
                text: msg.text,
                isError: msg.isError,
                isDark: isDark,
                onCopyCode: (code) =>
                    _copyToClipboard(code, 'Code snippet copied!'),
              ),

              if (!msg.isError && msg.sources.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildSourcesSection(msg.sources, isDark),
              ],

              // Action buttons (Copy response, Retry)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Text(
                      _formatTimestamp(msg.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.darkMuted2
                            : AppColors.lightMuted2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => _copyToClipboard(
                        msg.text,
                        'Response copied to clipboard',
                      ),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.copy_rounded,
                              size: 12,
                              color: isDark
                                  ? AppColors.darkMuted
                                  : AppColors.lightMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Copy',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkMuted
                                    : AppColors.lightMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (msg.isError && msg.lastSentPrompt != null) ...[
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => _send(retryText: msg.lastSentPrompt),
                        icon: const Icon(Icons.refresh, size: 12),
                        label: const Text('Retry response'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.cyan,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          minimumSize: Size.zero,
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Plan breakdown if provided
              if (msg.planTitle != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface2
                        : AppColors.lightSurface2,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.planTitle!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (
                        int s = 0;
                        s < (msg.planSteps?.length ?? 0);
                        s++
                      ) ...[
                        _planStep('${s + 1}', msg.planSteps![s]),
                        if (s < msg.planSteps!.length - 1)
                          const SizedBox(height: 6),
                      ],
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: widget.onOpenWizard,
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward, size: 14),
                        label: const Text('Review & create project'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThinkingIndicator(bool isDark) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.cyan.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: AnimatedWorkingDots(dotSize: 3, color: AppColors.cyan),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'AI is thinking & generating response…',
          style: TextStyle(
            color: AppColors.cyan,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        const AnimatedWorkingDots(dotSize: 3),
      ],
    );
  }

  String _formatTimestamp(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildSourcesSection(List<SourceCitation> sources, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.public,
              size: 12,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            ),
            const SizedBox(width: 5),
            Text(
              'Sources',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (int i = 0; i < sources.length; i++)
              _buildSourceChip(sources[i], i, isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceChip(SourceCitation source, int index, bool isDark) {
    final hasDomain =
        source.domain != null && source.domain!.trim().isNotEmpty;
    final hasDate =
        source.publishedDate != null && source.publishedDate!.trim().isNotEmpty;
    final displayTitle = source.title.trim().isNotEmpty
        ? source.title.trim()
        : (hasDomain ? source.domain!.trim() : source.url.trim());

    return InkWell(
      key: Key('citation_source_chip_$index'),
      onTap: () => _openCitationUrl(source),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.open_in_new,
              size: 12,
              color: AppColors.cyan,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayTitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasDomain || hasDate) ...[
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (hasDomain)
                          Text(
                            source.domain!.trim(),
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.darkMuted
                                  : AppColors.lightMuted,
                            ),
                          ),
                        if (hasDate)
                          Text(
                            source.publishedDate!.trim(),
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.darkMuted2
                                  : AppColors.lightMuted2,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFFA49AFF),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}

class _FormattedMessageView extends StatelessWidget {
  final String text;
  final bool isError;
  final bool isDark;
  final void Function(String code) onCopyCode;

  const _FormattedMessageView({
    required this.text,
    required this.isError,
    required this.isDark,
    required this.onCopyCode,
  });

  @override
  Widget build(BuildContext context) {
    if (isError) {
      final isRtl = VoiceLanguageService.isRtlText(text);
      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: SelectableText(
          text,
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          style: const TextStyle(color: AppColors.red, fontSize: 13, height: 1.5),
        ),
      );
    }

    // Split text by markdown code blocks (```lang ... ```)
    final codeBlockRegex = RegExp(r'```([a-zA-Z0-9_\-]*)\n([\s\S]*?)```');
    final List<Widget> widgets = [];
    int lastMatchEnd = 0;

    for (final match in codeBlockRegex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        final prose = text.substring(lastMatchEnd, match.start).trim();
        if (prose.isNotEmpty) {
          widgets.add(_buildProseText(prose));
          widgets.add(const SizedBox(height: 10));
        }
      }

      final language = match.group(1)?.trim();
      final codeContent = match.group(2)?.trimRight() ?? '';

      widgets.add(_buildCodeBlock(language, codeContent));
      widgets.add(const SizedBox(height: 10));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      final remainingProse = text.substring(lastMatchEnd).trim();
      if (remainingProse.isNotEmpty) {
        widgets.add(_buildProseText(remainingProse));
      }
    }

    if (widgets.isEmpty) {
      widgets.add(_buildProseText(text));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildProseText(String prose) {
    final isRtl = VoiceLanguageService.isRtlText(prose);
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: SizedBox(
        width: double.infinity,
        child: SelectableText(
          prose,
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          style: TextStyle(
            color: isDark ? AppColors.darkText : AppColors.lightText,
            fontSize: 13,
            height: isRtl ? 1.75 : 1.55,
            fontFamilyFallback: const [
              'Noto Nastaliq Urdu',
              'Noto Sans Arabic',
              'Arial',
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeBlock(String? language, String code) {
    final langLabel = (language != null && language.isNotEmpty)
        ? language
        : 'code';

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF070B14) : const Color(0xFF1E2433),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Code block top header bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: isDark ? const Color(0xFF0F1523) : const Color(0xFF161B29),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    langLabel.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cyan,
                      letterSpacing: 1.1,
                    ),
                  ),
                  InkWell(
                    onTap: () => onCopyCode(code),
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 12,
                            color: Colors.white70,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Copy code',
                            style: TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Code content
            Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.6,
                    color: Color(0xFFE2E8F0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
