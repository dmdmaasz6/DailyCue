import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../services/llm_service.dart';
import '../services/model_manager.dart';
import '../services/storage_service.dart';

enum ModelDownloadState { notStarted, downloading, downloaded, failed }

class AiChatProvider extends ChangeNotifier {
  final LlmService _llmService;
  final ModelManager _modelManager;
  final StorageService _storage;

  static const _uuid = Uuid();

  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  bool _isModelLoaded = false;
  bool get isModelLoaded => _isModelLoaded;

  ModelDownloadState _downloadState = ModelDownloadState.notStarted;
  ModelDownloadState get downloadState => _downloadState;

  double _downloadProgress = 0.0;
  double get downloadProgress => _downloadProgress;

  String? _downloadError;
  String? get downloadError => _downloadError;

  String _currentFile = '';
  String get currentFile => _currentFile;

  // Pending confirmation state
  Completer<bool>? _pendingConfirmation;
  String? _pendingToolName;
  Map<String, dynamic>? _pendingToolArgs;
  String? get pendingToolName => _pendingToolName;
  Map<String, dynamic>? get pendingToolArgs => _pendingToolArgs;
  bool get hasPendingConfirmation => _pendingConfirmation != null;

  AiChatProvider({
    required LlmService llmService,
    required ModelManager modelManager,
    required StorageService storage,
  })  : _llmService = llmService,
        _modelManager = modelManager,
        _storage = storage {
    _init();
  }

  Future<void> _init() async {
    // Load chat history
    _messages = _storage.getChatHistory();

    // Check model status
    final status = await _modelManager.getModelStatus();
    _downloadState = status == ModelStatus.downloaded
        ? ModelDownloadState.downloaded
        : ModelDownloadState.notStarted;

    notifyListeners();
  }

  Future<void> loadModel() async {
    if (_isModelLoaded) return;
    if (_downloadState != ModelDownloadState.downloaded) return;

    try {
      _isModelLoaded = await _llmService.loadModel();
      notifyListeners();
    } catch (e) {
      _isModelLoaded = false;
      notifyListeners();
    }
  }

  Future<void> downloadModel() async {
    if (_downloadState == ModelDownloadState.downloading) return;

    _downloadState = ModelDownloadState.downloading;
    _downloadProgress = 0.0;
    _downloadError = null;
    notifyListeners();

    try {
      await for (final progress in _modelManager.downloadModel()) {
        _downloadProgress = progress.fraction;
        _currentFile = progress.currentFile ?? '';
        notifyListeners();
      }

      _downloadState = ModelDownloadState.downloaded;
      _downloadProgress = 1.0;
      notifyListeners();
    } catch (e) {
      _downloadState = ModelDownloadState.failed;
      _downloadError = e.toString();
      notifyListeners();
    }
  }

  void cancelDownload() {
    _modelManager.cancelDownload();
    _downloadState = ModelDownloadState.notStarted;
    _downloadProgress = 0.0;
    notifyListeners();
  }

  Future<void> deleteModel() async {
    await _llmService.unloadModel();
    await _modelManager.deleteModel();
    _isModelLoaded = false;
    _downloadState = ModelDownloadState.notStarted;
    _downloadProgress = 0.0;
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

    // Ensure model is loaded
    if (!_isModelLoaded) {
      await loadModel();
      if (!_isModelLoaded) {
        final errorMsg = ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.assistant,
          content:
              'I need the AI model to be loaded first. Please make sure the model is downloaded and try again.',
        );
        _messages.add(errorMsg);
        await _storage.saveChatMessage(errorMsg);
        _isGenerating = false;
        notifyListeners();
        return;
      }
    }

    // Build context snapshot
    final now = DateTime.now();
    final contextSnapshot = _llmService.promptBuilder.buildContextSnapshot(
      now: now,
      todayActivityCount: _getTodayActivityCount(),
      todayCompletedCount: _getTodayCompletedCount(),
    );

    // Collect the response
    final responseBuffer = StringBuffer();
    final toolMessages = <ChatMessage>[];

    try {
      await for (final event in _llmService.chat(
        text.trim(),
        _messages.sublist(0, _messages.length - 1), // exclude just-added user msg
        contextSnapshot: contextSnapshot,
      )) {
        if (event is LlmTokenEvent) {
          responseBuffer.write(event.token);
          notifyListeners(); // Update UI with streaming text
        } else if (event is LlmToolCallEvent) {
          final toolCallMsg = ChatMessage(
            id: _uuid.v4(),
            role: ChatRole.toolCall,
            content: 'Calling ${event.name}...',
            toolName: event.name,
            toolArgs: event.arguments,
          );
          toolMessages.add(toolCallMsg);
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
          toolMessages.add(resultMsg);
          _messages.add(resultMsg);
          await _storage.saveChatMessage(resultMsg);
          notifyListeners();
        } else if (event is LlmConfirmEvent) {
          _pendingConfirmation = event.completer;
          _pendingToolName = event.toolName;
          _pendingToolArgs = event.arguments;
          notifyListeners();
          // Wait for user to confirm/deny
          await event.completer.future;
          _pendingConfirmation = null;
          _pendingToolName = null;
          _pendingToolArgs = null;
          notifyListeners();
        } else if (event is LlmDoneEvent) {
          // Add the final assistant message
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

  int _getTodayActivityCount() {
    // Access through tool executor's activity provider
    // This is a simplified count; the actual count comes from the tool
    return 0; // Will be populated when model runs get_today_schedule
  }

  int _getTodayCompletedCount() {
    return 0; // Will be populated when model runs get_today_schedule
  }
}
