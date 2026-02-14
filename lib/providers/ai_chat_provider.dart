import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../services/llm_backend.dart';
import '../services/llm_service.dart';
import '../services/prompt_builder.dart';
import '../services/storage_service.dart';
import 'activity_provider.dart';

class AiChatProvider extends ChangeNotifier {
  final LlmService _llmService;
  final StorageService _storage;
  final ActivityProvider _activityProvider;

  static const _uuid = Uuid();

  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  // Pending confirmation state
  Completer<bool>? _pendingConfirmation;
  String? _pendingToolName;
  Map<String, dynamic>? _pendingToolArgs;
  String? get pendingToolName => _pendingToolName;
  Map<String, dynamic>? get pendingToolArgs => _pendingToolArgs;
  bool get hasPendingConfirmation => _pendingConfirmation != null;

  AiChatProvider({
    required LlmService llmService,
    required StorageService storage,
    required ActivityProvider activityProvider,
  })  : _llmService = llmService,
        _storage = storage,
        _activityProvider = activityProvider {
    _init();
  }

  /// Whether the chat is ready for use (API key configured).
  bool get isReady {
    final key = _storage.openaiApiKey;
    return key != null && key.isNotEmpty;
  }

  void _init() {
    _messages = _storage.getChatHistory();
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (_isGenerating || text.trim().isEmpty) return;

    // Add user message
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      content: text.trim(),
    );
    _messages.add(userMessage);
    await _storage.saveChatMessage(userMessage);

    _isGenerating = true;
    notifyListeners();

    // Build context snapshot
    final now = DateTime.now();
    final contextSnapshot = PromptBuilder().buildContextSnapshot(
      now: now,
      todayActivityCount: _getTodayActivityCount(),
      todayCompletedCount: _getTodayCompletedCount(),
    );

    try {
      await for (final event in _llmService.chat(
        text.trim(),
        _messages.sublist(0, _messages.length - 1),
        contextSnapshot: contextSnapshot,
      )) {
        if (event is LlmTokenEvent) {
          notifyListeners();
        } else if (event is LlmToolCallEvent) {
          final toolCallMsg = ChatMessage(
            id: _uuid.v4(),
            role: ChatRole.toolCall,
            content: 'Calling ${event.name}...',
            toolName: event.name,
            toolArgs: event.arguments,
          );
          _messages.add(toolCallMsg);
          await _storage.saveChatMessage(toolCallMsg);
          notifyListeners();
        } else if (event is LlmToolResultEvent) {
          final resultMsg = ChatMessage(
            id: _uuid.v4(),
            role: ChatRole.toolResult,
            content: event.result,
            toolName: event.toolName,
            toolSuccess: true,
          );
          _messages.add(resultMsg);
          await _storage.saveChatMessage(resultMsg);
          notifyListeners();
        } else if (event is LlmConfirmEvent) {
          _pendingConfirmation = event.completer;
          _pendingToolName = event.toolName;
          _pendingToolArgs = event.arguments;
          notifyListeners();
          await event.completer.future;
          _pendingConfirmation = null;
          _pendingToolName = null;
          _pendingToolArgs = null;
          notifyListeners();
        } else if (event is LlmDoneEvent) {
          if (event.fullResponse.isNotEmpty) {
            final assistantMsg = ChatMessage(
              id: _uuid.v4(),
              role: ChatRole.assistant,
              content: event.fullResponse,
            );
            _messages.add(assistantMsg);
            await _storage.saveChatMessage(assistantMsg);
          }
        } else if (event is LlmErrorEvent) {
          final errorMsg = ChatMessage(
            id: _uuid.v4(),
            role: ChatRole.assistant,
            content: 'Sorry, I encountered an error: ${event.error}',
          );
          _messages.add(errorMsg);
          await _storage.saveChatMessage(errorMsg);
        }
      }
    } catch (e) {
      final errorMsg = ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        content: 'Sorry, something went wrong. Please try again.',
      );
      _messages.add(errorMsg);
      await _storage.saveChatMessage(errorMsg);
    }

    _isGenerating = false;
    notifyListeners();
  }

  void confirmToolAction(bool approved) {
    _pendingConfirmation?.complete(approved);
  }

  Future<void> clearChat() async {
    _messages.clear();
    await _storage.clearChatHistory();
    notifyListeners();
  }

  Future<void> stopGeneration() async {
    await _llmService.stopGeneration();
    _isGenerating = false;
    _pendingConfirmation?.complete(false);
    _pendingConfirmation = null;
    _pendingToolName = null;
    _pendingToolArgs = null;
    notifyListeners();
  }

  /// Switch the active LLM backend and re-initialize.
  Future<void> switchBackend(LlmBackend backend) async {
    _llmService.setBackend(backend);
    _init();
  }

  /// Re-initialize after settings change (e.g. API key update).
  void reinitialize() {
    _init();
  }

  int _getTodayActivityCount() {
    final now = DateTime.now();
    return _activityProvider.activities
        .where((a) => a.enabled && a.isActiveOn(now.weekday))
        .length;
  }

  int _getTodayCompletedCount() {
    final now = DateTime.now();
    return _activityProvider.activities
        .where((a) => a.enabled && a.isActiveOn(now.weekday) && a.isCompletedToday())
        .length;
  }
}
