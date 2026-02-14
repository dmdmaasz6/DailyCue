import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import 'llm_backend.dart';
import 'tool_executor.dart';

// Events emitted during LLM chat generation.
abstract class LlmEvent {}

class LlmTokenEvent extends LlmEvent {
  final String token;
  LlmTokenEvent(this.token);
}

class LlmToolCallEvent extends LlmEvent {
  final String name;
  final Map<String, dynamic> arguments;
  LlmToolCallEvent(this.name, this.arguments);
}

class LlmToolResultEvent extends LlmEvent {
  final String toolName;
  final String result;
  LlmToolResultEvent(this.toolName, this.result);
}

class LlmConfirmEvent extends LlmEvent {
  final String toolName;
  final Map<String, dynamic> arguments;
  final Completer<bool> completer;
  LlmConfirmEvent(this.toolName, this.arguments, this.completer);
}

class LlmDoneEvent extends LlmEvent {
  final String fullResponse;
  LlmDoneEvent(this.fullResponse);
}

class LlmErrorEvent extends LlmEvent {
  final String error;
  LlmErrorEvent(this.error);
}

class LlmService {
  LlmBackend _backend;
  final ToolExecutor _toolExecutor;

  static const _uuid = Uuid();
  static const int _maxToolRounds = 3;

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  LlmService({
    required LlmBackend backend,
    required ToolExecutor toolExecutor,
  })  : _backend = backend,
        _toolExecutor = toolExecutor;

  /// Swap the active backend (e.g. when switching between local and online).
  void setBackend(LlmBackend backend) {
    _backend = backend;
  }

  /// Main chat method. Takes user message and conversation history,
  /// yields events as the LLM generates a response (with tool calls).
  Stream<LlmEvent> chat(
    String userMessage,
    List<ChatMessage> history, {
    String? contextSnapshot,
  }) async* {
    if (_isGenerating) {
      yield LlmErrorEvent('Already generating a response');
      return;
    }

    _isGenerating = true;

    try {
      // Build conversation with the new user message
      final messages = List<ChatMessage>.from(history);
      messages.add(ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.user,
        content: userMessage,
      ));

      var fullResponse = '';
      var toolRound = 0;

      while (toolRound <= _maxToolRounds) {
        // Generate via the active backend
        final result = await _backend.generate(
          messages: messages,
          tools: _toolExecutor.tools,
          contextSnapshot: contextSnapshot,
        );

        if (!result.hasToolCall) {
          // Final text response
          final text = result.textContent;
          fullResponse += text;
          yield LlmTokenEvent(text);
          break;
        }

        // There's a tool call
        final toolCall = result.toolCall!;

        // Emit any text before the tool call
        if (toolCall.textBefore.isNotEmpty) {
          fullResponse += '${toolCall.textBefore}\n';
          yield LlmTokenEvent(toolCall.textBefore);
        }

        yield LlmToolCallEvent(toolCall.name, toolCall.arguments);

        // Add the assistant's tool call to conversation
        messages.add(ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.toolCall,
          content: 'Calling ${toolCall.name}...',
          toolName: toolCall.name,
          toolArgs: toolCall.arguments,
          toolCallId: toolCall.id,
        ));

        // Check if confirmation needed
        if (_toolExecutor.requiresConfirmation(toolCall.name)) {
          final completer = Completer<bool>();
          yield LlmConfirmEvent(
            toolCall.name,
            toolCall.arguments,
            completer,
          );

          final approved = await completer.future;
          if (!approved) {
            // User declined — add result and let LLM know
            messages.add(ChatMessage(
              id: _uuid.v4(),
              role: ChatRole.toolResult,
              content: '{"error": "User declined this action"}',
              toolName: toolCall.name,
              toolSuccess: false,
              toolCallId: toolCall.id,
            ));
            toolRound++;
            continue;
          }
        }

        // Execute the tool
        final toolResult = await _toolExecutor.execute(
          toolCall.name,
          toolCall.arguments,
        );

        yield LlmToolResultEvent(toolCall.name, toolResult);

        // Add tool result to conversation
        messages.add(ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.toolResult,
          content: toolResult,
          toolName: toolCall.name,
          toolSuccess: true,
          toolCallId: toolCall.id,
        ));

        toolRound++;
      }

      yield LlmDoneEvent(fullResponse);
    } catch (e) {
      yield LlmErrorEvent(e.toString());
    } finally {
      _isGenerating = false;
    }
  }

  Future<void> stopGeneration() async {
    await _backend.stopGeneration();
    _isGenerating = false;
  }
}
