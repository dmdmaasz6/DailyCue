import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../utils/constants.dart';
import 'model_manager.dart';
import 'onnx_channel.dart';
import 'prompt_builder.dart';
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
  final OnnxChannel _onnx;
  final ToolExecutor _toolExecutor;
  final PromptBuilder _promptBuilder;
  PromptBuilder get promptBuilder => _promptBuilder;
  final ModelManager _modelManager;

  static const _uuid = Uuid();
  static const int _maxToolRounds = 3;

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  LlmService({
    required OnnxChannel onnx,
    required ToolExecutor toolExecutor,
    required PromptBuilder promptBuilder,
    required ModelManager modelManager,
  })  : _onnx = onnx,
        _toolExecutor = toolExecutor,
        _promptBuilder = promptBuilder,
        _modelManager = modelManager;

  Future<bool> loadModel(String modelPath) async {
    return _onnx.loadModel(modelPath);
  }

  Future<void> unloadModel() async {
    await _onnx.unloadModel();
  }

  Future<bool> isModelLoaded() => _onnx.isModelLoaded();

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
        // Build prompt
        final prompt = _promptBuilder.buildPrompt(
          messages: messages,
          tools: _toolExecutor.tools,
          contextSnapshot: contextSnapshot,
        );

        // Generate response
        final response = await _onnx.generate(
          prompt,
          maxTokens: AppConstants.maxGenerationTokens,
          temperature: AppConstants.modelTemperature,
          topP: AppConstants.modelTopP,
          stopSequences: ['<|end|>', '<|user|>'],
        );

        // Check for tool call in response
        final toolCall = PromptBuilder.parseToolCall(response);

        if (toolCall == null) {
          // No tool call — this is the final text response
          final cleanResponse = response
              .replaceAll('<|end|>', '')
              .replaceAll('<|assistant|>', '')
              .trim();

          fullResponse += cleanResponse;
          yield LlmTokenEvent(cleanResponse);
          break;
        }

        // There's a tool call
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
          content: toolCall.fullMatch,
          toolName: toolCall.name,
          toolArgs: toolCall.arguments,
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
            ));
            toolRound++;
            continue;
          }
        }

        // Execute the tool
        final result = await _toolExecutor.execute(
          toolCall.name,
          toolCall.arguments,
        );

        yield LlmToolResultEvent(toolCall.name, result);

        // Add tool result to conversation
        messages.add(ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.toolResult,
          content: result,
          toolName: toolCall.name,
          toolSuccess: true,
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
    await _onnx.stopGeneration();
    _isGenerating = false;
  }
}
