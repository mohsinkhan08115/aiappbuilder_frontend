import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import 'neural_orb.dart';
import '../../data/services/api_service.dart';
import '../../data/services/audio_permission_service.dart';
import '../../data/services/speech_service.dart';
import '../../data/services/tts_service.dart';
import '../../data/services/voice_language_service.dart';
import '../../features/chat/view/chat_screen.dart';

/// Interaction state of the voice dialog interface.
enum VoiceDialogState { idle, listening, review, processing, speaking, error }

class VoiceDialog extends StatefulWidget {
  final VoidCallback onReturnToText;
  final ApiService? apiService;
  final SpeechService? speechService;
  final TtsService? ttsService;
  final AudioPermissionService? permissionService;
  final VoiceLanguageService? languageService;
  final VoiceLanguage initialLanguage;
  final String? conversationId;
  final Duration? autoSendDelay;
  final bool enableBargeIn;
  final void Function(String prompt, String response, String? conversationId)?
  onMessageExchanged;

  /// Default inactivity delay before automatically dispatching the final speech transcript.
  /// Reduced from 3 seconds to 1 second to minimize turn-taking latency.
  static const Duration defaultAutoSendDelay = Duration(milliseconds: 1000);

  const VoiceDialog({
    super.key,
    required this.onReturnToText,
    this.apiService,
    this.speechService,
    this.ttsService,
    this.permissionService,
    this.languageService,
    this.initialLanguage = VoiceLanguage.unknown,
    this.conversationId,
    this.autoSendDelay,
    this.enableBargeIn = true,
    this.onMessageExchanged,
  });

  @override
  State<VoiceDialog> createState() => _VoiceDialogState();
}

class _VoiceDialogState extends State<VoiceDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  // Injected or owned services
  late final AudioPermissionService _permissionService;
  late final SpeechService _speechService;
  late final TtsService _ttsService;
  late final VoiceLanguageService _languageService;
  final bool _ownsSpeechService;
  final bool _ownsTtsService;

  VoiceDialogState _state = VoiceDialogState.idle;
  late VoiceLanguage _selectedLanguage;
  LanguageDetectionResult? _detectionResult;
  bool _ttsPlaybackUnavailable = false;

  String _currentTranscript = '';
  String? _aiResponse;
  String? _errorMessage;
  bool _isPermanentlyDenied = false;
  bool _isSubmitting = false;
  double _soundLevel = 0.0;
  String? _activeConversationId;
  CancelToken? _cancelToken;
  int _activeTurnId = 0;

  // Auto-send timer: fires after the configured delay following final speech.
  Timer? _autoSendTimer;
  bool _pendingAutoSend = false;
  Duration get _autoSendDelay =>
      widget.autoSendDelay ?? VoiceDialog.defaultAutoSendDelay;

  _VoiceDialogState() : _ownsSpeechService = false, _ownsTtsService = false;

  ApiService get _apiService {
    if (widget.apiService != null) return widget.apiService!;
    try {
      return context.read<ApiService>();
    } catch (_) {
      return ApiService();
    }
  }

  VoiceLanguage get _effectiveLanguage {
    if (_selectedLanguage != VoiceLanguage.unknown) {
      return _selectedLanguage;
    }
    if (_detectionResult != null &&
        _detectionResult!.language != VoiceLanguage.unknown) {
      return _detectionResult!.language;
    }
    return VoiceLanguage.english;
  }

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _permissionService = widget.permissionService ?? AudioPermissionService();
    _languageService = widget.languageService ?? VoiceLanguageService();
    _selectedLanguage = widget.initialLanguage;

    if (widget.speechService != null) {
      _speechService = widget.speechService!;
    } else {
      _speechService = SpeechService();
    }

    if (widget.ttsService != null) {
      _ttsService = widget.ttsService!;
    } else {
      _ttsService = TtsService();
    }

    _activeConversationId = widget.conversationId;
    if (_activeConversationId == null &&
        ChatSessionMemory.threads != null &&
        ChatSessionMemory.threads!.isNotEmpty) {
      final thread =
          ChatSessionMemory.threads![ChatSessionMemory.selectedThread];
      _activeConversationId = thread.conversationId;
    }

    _wireServiceCallbacks();

    // Pre-initialize TTS service in the background to eliminate discovery
    // and engine loading latency from the critical path of the first AI response.
    _ttsService.initialize().then((_) {
      if (mounted) {
        _ttsService.refreshDiscovery();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Auto-send helpers
  // ---------------------------------------------------------------------------

  /// Cancels any pending auto-send timer and clears the countdown flag.
  void _cancelAutoSend() {
    _autoSendTimer?.cancel();
    _autoSendTimer = null;
    if (_pendingAutoSend) {
      setState(() {
        _pendingAutoSend = false;
      });
    }
  }

  /// Starts (or restarts) the 3-second inactivity auto-send timer.
  /// The timer only fires if a non-empty, non-submitted transcript exists.
  void _scheduleAutoSend() {
    _autoSendTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _pendingAutoSend = true;
    });
    _autoSendTimer = Timer(_autoSendDelay, () async {
      _autoSendTimer = null;
      if (!mounted) return;
      setState(() {
        _pendingAutoSend = false;
      });
      if (_currentTranscript.trim().isEmpty || _isSubmitting) return;
      await _sendTranscriptToAi();
    });
  }

  // ---------------------------------------------------------------------------

  void _wireServiceCallbacks() {
    _speechService.onStateChanged = (serviceState) {
      if (!mounted) return;
      if (serviceState == SpeechServiceState.ready &&
          _state == VoiceDialogState.listening) {
        setState(() {
          if (_currentTranscript.trim().isNotEmpty) {
            _state = VoiceDialogState.review;
            _detectionResult = _languageService.detectLanguage(
              text: _currentTranscript,
              userSelection: _selectedLanguage,
              engineLocale: _speechService.selectedLocaleId,
            );
          } else {
            _state = VoiceDialogState.error;
            _errorMessage = 'No speech was detected. Please try again.';
          }
        });

        // If the engine terminated naturally and a transcript is available but
        // no auto-send timer is already running, start one now.
        if (_currentTranscript.trim().isNotEmpty && _autoSendTimer == null) {
          _scheduleAutoSend();
        } else if (_currentTranscript.trim().isEmpty) {
          _cancelAutoSend();
        }
      }
    };

    _speechService.onResult = (result) {
      if (!mounted) return;

      // Barge-in interruption: If user speaks during speaking or processing,
      // halt audio/request immediately and switch back to listening.
      if (widget.enableBargeIn &&
          (_state == VoiceDialogState.speaking ||
              _state == VoiceDialogState.processing) &&
          result.words.trim().isNotEmpty) {
        if (_state == VoiceDialogState.speaking &&
            _isLikelyEcho(result.words, _aiResponse)) {
          return;
        }
        _handleBargeIn(result);
        return;
      }

      setState(() {
        _currentTranscript = result.words;
        if (_state == VoiceDialogState.idle && result.words.trim().isNotEmpty) {
          _state = VoiceDialogState.listening;
        }
        _detectionResult = _languageService.detectLanguage(
          text: _currentTranscript,
          userSelection: _selectedLanguage,
          engineLocale: _speechService.selectedLocaleId,
        );

        if (result.isFinal) {
          if (result.words.trim().isNotEmpty) {
            _state = VoiceDialogState.review;
          } else {
            _state = VoiceDialogState.error;
            _errorMessage = 'No speech was detected. Please try again.';
          }
        }
      });

      // Schedule auto-send after a final non-empty result.
      // Cancel any pending timer on an interim result (user still speaking).
      if (result.isFinal) {
        if (result.words.trim().isNotEmpty) {
          _scheduleAutoSend();
        } else {
          _cancelAutoSend();
        }
      } else {
        // Interim result — user is still speaking; reset any pending countdown.
        if (_pendingAutoSend) {
          _cancelAutoSend();
        }
      }
    };

    _speechService.onSoundLevelChange = (level) {
      if (!mounted) return;
      setState(() {
        _soundLevel = level;
      });
    };

    _speechService.onError = (error) {
      if (!mounted) return;
      setState(() {
        _state = VoiceDialogState.error;
        _errorMessage = error.message;
        _isPermanentlyDenied = error.permanent;
      });
    };

    _ttsService.onCompletion = () {
      if (!mounted) return;
      if (_state == VoiceDialogState.speaking) {
        setState(() {
          _state = VoiceDialogState.idle;
        });
        if (_speechService.isListening) {
          _speechService.stopListening();
        }
      }
    };

    _ttsService.onCancel = () {
      if (!mounted) return;
      if (_state == VoiceDialogState.speaking) {
        setState(() {
          _state = VoiceDialogState.idle;
        });
        if (_speechService.isListening) {
          _speechService.stopListening();
        }
      }
    };

    _ttsService.onError = (error) {
      if (!mounted) return;
      debugPrint('VoiceDialog TTS error: ${error.message}');
      if (_state == VoiceDialogState.speaking) {
        setState(() {
          _state = VoiceDialogState.idle;
        });
        if (_speechService.isListening) {
          _speechService.stopListening();
        }
      }
    };
  }

  /// Detects whether recognized words during TTS playback might simply be
  /// acoustic speaker feedback rather than an intentional user utterance.
  bool _isLikelyEcho(String spoken, String? aiText) {
    if (aiText == null || aiText.trim().isEmpty) return false;
    final cleanSpoken = spoken.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final cleanAi = aiText.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (cleanSpoken.isEmpty) return true;

    // High-intent interruption keywords always trigger barge-in regardless of echo check
    const highIntentWords = {
      'stop',
      'wait',
      'no',
      'cancel',
      'pause',
      'hold on',
      'hey',
      'listen',
      'quiet',
    };
    if (highIntentWords.contains(cleanSpoken)) return false;

    final wordCount = cleanSpoken.split(RegExp(r'\s+')).length;
    if (wordCount <= 2 && cleanAi.contains(cleanSpoken) && cleanSpoken.length < 20) {
      return true;
    }
    return false;
  }

  /// Handles barge-in when the user speaks while AI audio is playing or
  /// while an AI response request is currently in-flight.
  void _handleBargeIn(SpeechResult result) {
    _activeTurnId++; // Invalidate in-flight response and discard stale output
    _cancelToken?.cancel('Barge-in: user started speaking');
    _cancelToken = null;
    _isSubmitting = false;

    setState(() {
      _currentTranscript = result.words;
      _aiResponse = null;
      _errorMessage = null;
      _ttsPlaybackUnavailable = false;
      _state = result.isFinal ? VoiceDialogState.review : VoiceDialogState.listening;
      _detectionResult = _languageService.detectLanguage(
        text: _currentTranscript,
        userSelection: _selectedLanguage,
        engineLocale: _speechService.selectedLocaleId,
      );
    });

    if (_ttsService.isSpeaking) {
      _ttsService.stop();
    }

    if (result.isFinal) {
      if (result.words.trim().isNotEmpty) {
        _scheduleAutoSend();
      } else {
        _cancelAutoSend();
      }
    } else {
      if (_pendingAutoSend) {
        _cancelAutoSend();
      }
    }
  }

  /// Starts speech recognition during speaking or processing states to support barge-in.
  Future<void> _startBargeInListening() async {
    if (!widget.enableBargeIn || !mounted) return;
    if (_speechService.isListening) return;

    try {
      final perm = await _permissionService.checkPermission();
      if (!perm.isGranted || !mounted) return;

      final requestedLocale = _selectedLanguage != VoiceLanguage.unknown
          ? _selectedLanguage.localeId
          : null;

      await _speechService.startListening(
        localeId: requestedLocale,
        partialResults: true,
      );
    } catch (e) {
      debugPrint('VoiceDialog: barge-in listening start error: $e');
    }
  }

  @override
  void dispose() {
    _activeTurnId++;
    _autoSendTimer?.cancel();
    _autoSendTimer = null;
    _cancelToken?.cancel('Voice dialog closed');

    if (_speechService.isListening) {
      _speechService.cancelListening();
    }

    if (_ttsService.isSpeaking) {
      _ttsService.stop();
    }

    if (_ownsSpeechService) {
      _speechService.dispose();
    }
    if (_ownsTtsService) {
      _ttsService.dispose();
    }

    _anim.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (_state == VoiceDialogState.listening || _isSubmitting) return;

    // Cancel any pending auto-send from a previous recording session.
    _autoSendTimer?.cancel();
    _autoSendTimer = null;
    _pendingAutoSend = false;

    if (_ttsService.isSpeaking) {
      await _ttsService.stop();
    }

    setState(() {
      _errorMessage = null;
      _isPermanentlyDenied = false;
      _ttsPlaybackUnavailable = false;
    });

    final permissionStatus = await _permissionService.checkPermission();
    if (!permissionStatus.isGranted) {
      final requestedStatus = await _permissionService.requestPermission();
      if (!mounted) return;

      if (requestedStatus.isPermanentlyDenied) {
        setState(() {
          _state = VoiceDialogState.error;
          _isPermanentlyDenied = true;
          _errorMessage =
              'Microphone permission is permanently denied. Please enable it in system settings.';
        });
        return;
      }

      if (!requestedStatus.isGranted) {
        setState(() {
          _state = VoiceDialogState.error;
          _isPermanentlyDenied = false;
          _errorMessage =
              'Microphone permission is required to use voice input.';
        });
        return;
      }
    }

    final initialized = await _speechService.initialize();
    if (!mounted) return;

    if (!initialized) {
      setState(() {
        _state = VoiceDialogState.error;
        _errorMessage =
            _speechService.lastError?.message ??
            'Failed to initialize speech engine.';
      });
      return;
    }

    setState(() {
      _state = VoiceDialogState.listening;
      _currentTranscript = '';
      _soundLevel = 0.0;
    });

    final requestedLocale = _selectedLanguage != VoiceLanguage.unknown
        ? _selectedLanguage.localeId
        : null;

    await _speechService.startListening(localeId: requestedLocale);
  }

  Future<void> _stopListening() async {
    if (_state != VoiceDialogState.listening) return;

    await _speechService.stopListening();
    if (!mounted) return;

    setState(() {
      if (_currentTranscript.trim().isEmpty) {
        _state = VoiceDialogState.error;
        _errorMessage = 'No speech was detected. Please try again.';
      } else {
        _state = VoiceDialogState.review;
        _detectionResult = _languageService.detectLanguage(
          text: _currentTranscript,
          userSelection: _selectedLanguage,
          engineLocale: _speechService.selectedLocaleId,
        );
      }
    });
  }

  Future<void> _cancelListening() async {
    _autoSendTimer?.cancel();
    _autoSendTimer = null;
    _pendingAutoSend = false;
    await _speechService.cancelListening();
    if (!mounted) return;

    setState(() {
      _state = VoiceDialogState.idle;
      _currentTranscript = '';
      _soundLevel = 0.0;
      _errorMessage = null;
    });
  }

  Future<void> _sendTranscriptToAi() async {
    final prompt = _currentTranscript.trim();
    if (prompt.isEmpty || _isSubmitting) return;

    // Cancel any pending auto-send timer to prevent duplicate submission.
    _autoSendTimer?.cancel();
    _autoSendTimer = null;
    _pendingAutoSend = false;
    final int turnId = ++_activeTurnId;

    final targetLang = _effectiveLanguage;
    final systemInstruction = _languageService.buildSystemInstruction(
      targetLang,
    );

    setState(() {
      _isSubmitting = true;
      _state = VoiceDialogState.processing;
      _errorMessage = null;
      _ttsPlaybackUnavailable = false;
    });

    if (widget.enableBargeIn) {
      _startBargeInListening();
    }

    _cancelToken = CancelToken();

    try {
      final res = await _apiService.sendChatMessage(
        prompt,
        conversationId: _activeConversationId,
        systemInstruction: systemInstruction,
        cancelToken: _cancelToken,
      );

      if (!mounted || turnId != _activeTurnId) return;

      _activeConversationId = res.conversationId;
      _aiResponse = res.response;

      _recordInConversationHistory(
        prompt,
        res.response,
        res.conversationId,
        sources: res.sources,
        searchQueries: res.searchQueries,
      );

      widget.onMessageExchanged?.call(prompt, res.response, res.conversationId);

      // Verify TTS service initialization (pre-warmed during initState)
      if (!_ttsService.isInitialized) {
        await _ttsService.initialize();
        await _ttsService.refreshDiscovery();
      }

      if (!mounted || turnId != _activeTurnId) return;

      final supportedTtsLocale = _languageService.resolveTtsLocale(
        language: targetLang,
        isLocaleSupported: _ttsService.isLanguageSupported,
      );

      if (supportedTtsLocale != null) {
        setState(() {
          _isSubmitting = false;
          _state = VoiceDialogState.speaking;
        });

        if (widget.enableBargeIn) {
          _startBargeInListening();
        }

        await _ttsService.setLanguage(supportedTtsLocale);
        if (!mounted || turnId != _activeTurnId) return;

        final speakOk = await _ttsService.speak(res.response);
        if (!speakOk && mounted && turnId == _activeTurnId) {
          setState(() {
            _ttsPlaybackUnavailable = true;
            if (_state == VoiceDialogState.speaking) {
              _state = VoiceDialogState.idle;
            }
          });
        }
      } else {
        // Target language is not supported by device TTS engine (e.g. Pashto without voice data).
        // Keep AI response fully visible and show honest playback-unavailable state.
        setState(() {
          _isSubmitting = false;
          _ttsPlaybackUnavailable = true;
          _state = VoiceDialogState.idle;
        });
      }
    } catch (e) {
      if (!mounted || turnId != _activeTurnId) return;
      if (e is DioException && CancelToken.isCancel(e)) return;
      final parsedError = e.toString().replaceFirst(
        RegExp(r'^Exception:\s*'),
        '',
      );
      setState(() {
        _isSubmitting = false;
        _state = VoiceDialogState.error;
        _errorMessage = 'AI request failed: $parsedError';
      });
    } finally {
      if (turnId == _activeTurnId) {
        _cancelToken = null;
      }
    }
  }

  /// User-triggered manual playback of the active AI response.
  /// Bypasses browser autoplay restrictions via direct user interaction.
  Future<void> _playAiResponse() async {
    final responseText = _aiResponse?.trim();
    if (responseText == null || responseText.isEmpty || _isSubmitting) return;

    if (_ttsService.isSpeaking) {
      await _stopSpeaking();
      return;
    }

    setState(() {
      _ttsPlaybackUnavailable = false;
      _errorMessage = null;
    });

    if (!_ttsService.isInitialized) {
      await _ttsService.initialize();
      await _ttsService.refreshDiscovery();
    }

    final targetLang = _effectiveLanguage;
    final supportedTtsLocale = _languageService.resolveTtsLocale(
      language: targetLang,
      isLocaleSupported: _ttsService.isLanguageSupported,
    );

    if (supportedTtsLocale != null) {
      setState(() {
        _state = VoiceDialogState.speaking;
      });

      if (widget.enableBargeIn) {
        _startBargeInListening();
      }

      await _ttsService.setLanguage(supportedTtsLocale);
      final speakOk = await _ttsService.speak(responseText);
      if (!speakOk && mounted) {
        setState(() {
          _ttsPlaybackUnavailable = true;
          if (_state == VoiceDialogState.speaking) {
            _state = VoiceDialogState.idle;
          }
        });
      }
    } else {
      setState(() {
        _ttsPlaybackUnavailable = true;
        if (_state == VoiceDialogState.speaking) {
          _state = VoiceDialogState.idle;
        }
      });
    }
  }

  void _recordInConversationHistory(
    String prompt,
    String response,
    String conversationId, {
    List<SourceCitation> sources = const [],
    List<String> searchQueries = const [],
  }) {
    if (ChatSessionMemory.threads == null ||
        ChatSessionMemory.threads!.isEmpty) {
      ChatSessionMemory.threads = [
        ChatThread(
          title: 'Voice Session',
          subtitle: 'Active conversation',
          conversationId: conversationId,
          messages: [],
        ),
      ];
      ChatSessionMemory.selectedThread = 0;
    }

    final thread = ChatSessionMemory.threads![ChatSessionMemory.selectedThread];
    thread.conversationId = conversationId;
    thread.messages.add(
      ChatMessage(text: prompt, isUser: true, timestamp: DateTime.now()),
    );
    thread.messages.add(
      ChatMessage(
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
        sources: sources,
        searchQueries: searchQueries,
      ),
    );
  }

  Future<void> _stopSpeaking() async {
    await _ttsService.stop();
    if (_speechService.isListening) {
      await _speechService.stopListening();
    }
    if (!mounted) return;
    setState(() {
      _state = VoiceDialogState.idle;
    });
  }

  void _onLanguageSelected(VoiceLanguage lang) {
    setState(() {
      _selectedLanguage = lang;
      if (_currentTranscript.isNotEmpty) {
        _detectionResult = _languageService.detectLanguage(
          text: _currentTranscript,
          userSelection: _selectedLanguage,
          engineLocale: _speechService.selectedLocaleId,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark
              ? AppColors.darkBorderBright
              : AppColors.lightBorderBright,
        ),
      ),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Talk to AI',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusPill(isDark),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Language Selection Bar
                _buildLanguageSelector(isDark),
                const SizedBox(height: 12),

                // Visual Orb
                NeuralOrb(
                  isThinking: _state == VoiceDialogState.processing,
                  size: 90,
                ),
                const SizedBox(height: 16),

                // Title and Subtitle
                Text(
                  _getStatusTitle(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  _getStatusSubtitle(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.darkMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),

                // Waveform Display
                _buildWaveformDisplay(),
                const SizedBox(height: 14),

                // Transcript & Response Card
                if (_currentTranscript.isNotEmpty || _aiResponse != null)
                  _buildMessageHistoryCard(isDark),

                // TTS Playback Unavailable Banner
                if (_ttsPlaybackUnavailable) _buildTtsUnavailableBanner(isDark),

                // Error Banner
                if (_state == VoiceDialogState.error && _errorMessage != null)
                  _buildErrorBanner(isDark),

                const SizedBox(height: 16),

                // Primary Action Controls
                _buildActionControls(),

                const SizedBox(height: 20),

                // Navigation Controls
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 14),
                      label: const Text('End'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onReturnToText();
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 14),
                      label: const Text('Return to text'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141923) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          const Icon(Icons.language, size: 14, color: AppColors.cyan),
          const Text(
            'Language: ',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<VoiceLanguage>(
              value: _selectedLanguage,
              isDense: true,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              items: const [
                DropdownMenuItem(
                  value: VoiceLanguage.unknown,
                  child: Text('Auto Detect'),
                ),
                DropdownMenuItem(
                  value: VoiceLanguage.english,
                  child: Text('English'),
                ),
                DropdownMenuItem(
                  value: VoiceLanguage.urdu,
                  child: Text('Urdu (اردو)'),
                ),
                DropdownMenuItem(
                  value: VoiceLanguage.pashto,
                  child: Text('Pashto (پښتو)'),
                ),
              ],
              onChanged: _state == VoiceDialogState.listening || _isSubmitting
                  ? null
                  : (val) {
                      if (val != null) _onLanguageSelected(val);
                    },
            ),
          ),
          if (_selectedLanguage == VoiceLanguage.unknown &&
              _detectionResult != null &&
              _detectionResult!.language != VoiceLanguage.unknown) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _detectionResult!.language.displayName,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.cyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusPill(bool isDark) {
    Color bg;
    Color fg;
    String label;

    switch (_state) {
      case VoiceDialogState.listening:
        bg = AppColors.cyan.withValues(alpha: 0.15);
        fg = AppColors.cyan;
        label = 'Listening';
        break;
      case VoiceDialogState.review:
        bg = AppColors.primary.withValues(alpha: 0.15);
        fg = AppColors.primary;
        label = 'Review';
        break;
      case VoiceDialogState.processing:
        bg = Colors.amber.withValues(alpha: 0.15);
        fg = Colors.amber;
        label = 'Thinking';
        break;
      case VoiceDialogState.speaking:
        bg = Colors.green.withValues(alpha: 0.15);
        fg = Colors.green;
        label = 'Speaking';
        break;
      case VoiceDialogState.error:
        bg = Colors.red.withValues(alpha: 0.15);
        fg = Colors.redAccent;
        label = 'Error';
        break;
      case VoiceDialogState.idle:
        bg = isDark ? Colors.white10 : Colors.black12;
        fg = isDark ? Colors.white70 : Colors.black87;
        label = 'Ready';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _getStatusTitle() {
    switch (_state) {
      case VoiceDialogState.listening:
        return 'Listening to you...';
      case VoiceDialogState.review:
        return 'Review your message';
      case VoiceDialogState.processing:
        return 'AI is thinking...';
      case VoiceDialogState.speaking:
        return 'AI is speaking';
      case VoiceDialogState.error:
        return 'Voice Assistant';
      case VoiceDialogState.idle:
        return _aiResponse != null ? 'Conversation Ready' : 'Talk to AI';
    }
  }

  String _getStatusSubtitle() {
    switch (_state) {
      case VoiceDialogState.listening:
        return 'Speak in ${_effectiveLanguage.displayName}. Tap Stop when finished.';
      case VoiceDialogState.review:
        if (_pendingAutoSend) {
          final totalMs = _autoSendDelay.inMilliseconds;
          final String timeStr;
          if (totalMs % 1000 == 0) {
            final secs = totalMs ~/ 1000;
            timeStr = secs == 1 ? '1 second' : '$secs seconds';
          } else {
            final secs = (totalMs / 1000.0).toStringAsFixed(1);
            timeStr = '$secs seconds';
          }
          return 'Sending in $timeStr… Speak again or tap Cancel to stop.';
        }
        return 'Review transcript below. Target response language: ${_effectiveLanguage.displayName}.';
      case VoiceDialogState.processing:
        return 'Requesting response in ${_effectiveLanguage.displayName}...';
      case VoiceDialogState.speaking:
        return 'Playing audio response in ${_effectiveLanguage.displayName}.';
      case VoiceDialogState.error:
        return 'Please review the issue below and try again.';
      case VoiceDialogState.idle:
        return _aiResponse != null
            ? 'Tap the microphone to speak another request.'
            : 'Tap the microphone below to start speaking.';
    }
  }

  Widget _buildWaveformDisplay() {
    final isListening = _state == VoiceDialogState.listening;
    final isSpeaking = _state == VoiceDialogState.speaking;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return SizedBox(
          height: 38,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(24, (i) {
              final wave =
                  (math.sin((_anim.value * 2 * math.pi) + (i * 0.4)) + 1) / 2;

              double h = 6;
              if (isListening) {
                final boost = (_soundLevel.clamp(0.0, 40.0) / 40.0);
                h = 6 + (wave * (16 + boost * 16));
              } else if (isSpeaking) {
                h = 6 + (wave * 26);
              }

              return Container(
                width: 3,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    colors: isListening
                        ? [AppColors.cyan, AppColors.primary]
                        : isSpeaking
                        ? [Colors.greenAccent, AppColors.cyan]
                        : [Colors.grey.shade600, Colors.grey.shade400],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildMessageHistoryCard(bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 140),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141923) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentTranscript.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 12,
                    color: AppColors.cyan,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'You said:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cyan,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _effectiveLanguage.displayName,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.cyan,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(_currentTranscript, style: const TextStyle(fontSize: 13)),
            ],
            if (_currentTranscript.isNotEmpty && _aiResponse != null)
              const Divider(height: 16),
            if (_aiResponse != null) ...[
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 12, color: Colors.green),
                  const SizedBox(width: 4),
                  const Text(
                    'AI response:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _state == VoiceDialogState.speaking
                          ? Icons.volume_off
                          : Icons.volume_up,
                      size: 16,
                      color: _state == VoiceDialogState.speaking
                          ? Colors.redAccent
                          : AppColors.cyan,
                    ),
                    tooltip: _state == VoiceDialogState.speaking
                        ? 'Stop speaking'
                        : 'Play AI voice',
                    onPressed: _state == VoiceDialogState.speaking
                        ? _stopSpeaking
                        : _playAiResponse,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(_aiResponse!, style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTtsUnavailableBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.volume_off, size: 16, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Voice playback is not supported on this device for ${_effectiveLanguage.displayName}. Text response is shown above.',
              style: const TextStyle(color: Colors.amber, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? 'An unexpected error occurred.',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
          if (_isPermanentlyDenied)
            TextButton(
              onPressed: () => _permissionService.openSettings(),
              child: const Text('Settings', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }

  Widget _buildActionControls() {
    if (_state == VoiceDialogState.listening) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: _stopListening,
            icon: const Icon(Icons.stop, size: 16),
            label: const Text('Stop Recording'),
          ),
          OutlinedButton(
            onPressed: _cancelListening,
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    if (_state == VoiceDialogState.review) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: _sendTranscriptToAi,
            icon: const Icon(Icons.send, size: 14),
            label: const Text('Send to AI'),
          ),
          OutlinedButton.icon(
            onPressed: _startListening,
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('Re-record'),
          ),
          if (_pendingAutoSend)
            OutlinedButton.icon(
              onPressed: _cancelAutoSend,
              icon: const Icon(Icons.cancel_outlined, size: 14),
              label: const Text('Cancel Auto-send'),
            ),
        ],
      );
    }

    if (_state == VoiceDialogState.processing) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text(
            'Processing request...',
            style: TextStyle(fontSize: 12, color: AppColors.darkMuted),
          ),
        ],
      );
    }

    if (_state == VoiceDialogState.speaking) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: _stopSpeaking,
            icon: const Icon(Icons.volume_off, size: 16),
            label: const Text('Stop Speaking'),
          ),
          OutlinedButton.icon(
            onPressed: _startListening,
            icon: const Icon(Icons.mic, size: 14),
            label: const Text('Speak Again'),
          ),
        ],
      );
    }

    // Default: Idle or Error state
    if (_aiResponse != null) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: _playAiResponse,
            icon: const Icon(Icons.volume_up, size: 16),
            label: const Text('Play AI Voice'),
          ),
          OutlinedButton.icon(
            onPressed: _startListening,
            icon: const Icon(Icons.mic, size: 16),
            label: const Text('Speak Again'),
          ),
        ],
      );
    }

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: _startListening,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.cyan, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyan.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}
