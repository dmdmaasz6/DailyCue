import '../models/chat_message.dart';
import '../models/llm_tool.dart';

/// Result of a single LLM generation turn.
class LlmGenerationResult {
  /// Text content of the response (may be empty if only a tool call).
  final String textContent;

  /// Tool call, if the model wants to invoke a tool.
  final LlmToolCallResult? toolCall;

  const LlmGenerationResult({
    this.textContent = '',
    this.toolCall,
  });

  bool get hasToolCall => toolCall != null;
}

/// A parsed tool call from the LLM response.
class LlmToolCallResult {
  /// Unique identifier for this tool call (used by OpenAI, generated for ONNX).
  final String id;

  /// Tool function name.
  final String name;

  /// Tool arguments as a map.
  final Map<String, dynamic> arguments;

  /// Any text the model emitted before the tool call.
  final String textBefore;

  const LlmToolCallResult({
    required this.id,
    required this.name,
    required this.arguments,
    this.textBefore = '',
  });
}

/// Abstract interface for LLM inference backends.
///
/// Implementations provide a single-turn generation method. The tool-calling
/// loop is managed by [LlmService], which calls [generate] repeatedly until
/// the model produces a final text response (no tool call).
abstract class LlmBackend {
  /// Generate a response for the given conversation.
  ///
  /// [messages] is the full conversation history including tool call/result
  /// messages from the current session.
  /// [tools] is the list of available tools the model can call.
  /// [contextSnapshot] is optional context about the current time and progress.
  Future<LlmGenerationResult> generate({
    required List<ChatMessage> messages,
    required List<LlmTool> tools,
    String? contextSnapshot,
  });

  /// Cancel any ongoing generation.
  Future<void> stopGeneration();

  /// Whether this backend requires a local model to be downloaded and loaded.
  bool get requiresLocalModel;
}
