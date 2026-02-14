import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/llm_tool.dart';
import '../utils/constants.dart';
import 'llm_backend.dart';
import 'onnx_channel.dart';
import 'prompt_builder.dart';

/// LLM backend that runs inference locally using ONNX Runtime GenAI.
class OnnxBackend extends LlmBackend {
  final OnnxChannel _onnx;
  final PromptBuilder _promptBuilder;

  static const _uuid = Uuid();

  OnnxBackend({
    required OnnxChannel onnx,
    required PromptBuilder promptBuilder,
  })  : _onnx = onnx,
        _promptBuilder = promptBuilder;

  @override
  bool get requiresLocalModel => true;

  /// Access the underlying channel for model load/unload operations.
  OnnxChannel get onnxChannel => _onnx;

  /// Access the prompt builder for context snapshot building.
  PromptBuilder get promptBuilder => _promptBuilder;

  @override
  Future<LlmGenerationResult> generate({
    required List<ChatMessage> messages,
    required List<LlmTool> tools,
    String? contextSnapshot,
  }) async {
    // Build the full Phi-4 chat template prompt
    final prompt = _promptBuilder.buildPrompt(
      messages: messages,
      tools: tools,
      contextSnapshot: contextSnapshot,
    );

    // Run local inference
    final response = await _onnx.generate(
      prompt,
      maxTokens: AppConstants.maxGenerationTokens,
      temperature: AppConstants.modelTemperature,
      topP: AppConstants.modelTopP,
      stopSequences: ['<|end|>', '<|user|>'],
    );

    // Check for tool call in the response
    final toolCall = PromptBuilder.parseToolCall(response);

    if (toolCall != null) {
      return LlmGenerationResult(
        textContent: '',
        toolCall: LlmToolCallResult(
          id: 'call_${_uuid.v4()}',
          name: toolCall.name,
          arguments: toolCall.arguments,
          textBefore: toolCall.textBefore,
        ),
      );
    }

    // No tool call — clean up the text response
    var cleaned = response;

    for (final marker in ['<|user|>', '<|end|>']) {
      final idx = cleaned.indexOf(marker);
      if (idx >= 0) {
        cleaned = cleaned.substring(0, idx);
      }
    }

    cleaned = cleaned.replaceAll('<|assistant|>', '').trim();

    return LlmGenerationResult(textContent: cleaned);
  }

  @override
  Future<void> stopGeneration() async {
    await _onnx.stopGeneration();
  }
}
