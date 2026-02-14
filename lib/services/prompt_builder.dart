import 'dart:convert';
import '../models/chat_message.dart';
import '../models/llm_tool.dart';
import '../utils/constants.dart';

class PromptBuilder {
  /// Core system prompt shared by all backends (persona + guidelines).
  static const String coreSystemPrompt =
      '''You are DailyCue AI Coach, a helpful life balance assistant embedded in a daily activity planner app. You help users understand their habits, improve their routines, and build a balanced life across these categories: General, Health, Work, Personal, Fitness, Family, Errands, and Learning.

You have access to tools to read and modify the user's activity data. Always check the user's data before giving advice.

## Guidelines
- Be concise, warm, and encouraging
- Ground all advice in the user's actual data — never guess
- When suggesting new activities, use the create_activity tool
- Always check statistics before making claims about patterns
- Ask before making changes to existing activities
- For write operations (create/update), explain what you want to do first
- Keep responses to 2-3 short paragraphs maximum
- Use simple language, no jargon''';

  /// ONNX-specific tool-calling instructions appended to the system prompt
  /// for local models that use text-based tool calling.
  static const String _onnxToolCallingInstructions =
      '''

## Tool Calling
To use a tool, respond ONLY with a tool call in this exact format:
<tool_call>{"name": "tool_name", "arguments": {"param": "value"}}</tool_call>

After receiving the tool result, continue your response using that data. You may call multiple tools in sequence (one at a time) before giving your final answer.''';

  String buildToolDefinitions(List<LlmTool> tools) {
    final toolDefs = tools.map((t) => t.toSchemaJson()).toList();
    return '\n\n## Available Tools\n${jsonEncode(toolDefs)}';
  }

  String buildPrompt({
    required List<ChatMessage> messages,
    required List<LlmTool> tools,
    String? contextSnapshot,
  }) {
    final buffer = StringBuffer();

    // System prompt with ONNX tool-calling instructions and tool definitions
    buffer.write('<|system|>\n');
    buffer.write(coreSystemPrompt);
    buffer.write(_onnxToolCallingInstructions);
    buffer.write(buildToolDefinitions(tools));
    if (contextSnapshot != null) {
      buffer.write('\n\n## Current Context\n');
      buffer.write(contextSnapshot);
    }
    buffer.write('<|end|>\n');

    // Conversation history (trimmed to fit context budget)
    final trimmedMessages = _trimMessages(messages);

    for (final message in trimmedMessages) {
      switch (message.role) {
        case ChatRole.user:
          buffer.write('<|user|>\n');
          buffer.write(message.content);
          buffer.write('<|end|>\n');
          break;
        case ChatRole.assistant:
          buffer.write('<|assistant|>\n');
          buffer.write(message.content);
          buffer.write('<|end|>\n');
          break;
        case ChatRole.toolCall:
          buffer.write('<|assistant|>\n');
          buffer.write('<tool_call>');
          buffer.write(jsonEncode({
            'name': message.toolName,
            'arguments': message.toolArgs,
          }));
          buffer.write('</tool_call>');
          buffer.write('<|end|>\n');
          break;
        case ChatRole.toolResult:
          buffer.write('<|tool_result|>\n');
          buffer.write(message.content);
          buffer.write('<|end|>\n');
          break;
        case ChatRole.system:
          // System messages are already included at the start
          break;
      }
    }

    // Open the assistant turn for generation
    buffer.write('<|assistant|>\n');

    return buffer.toString();
  }

  String buildContextSnapshot({
    required DateTime now,
    required int todayActivityCount,
    required int todayCompletedCount,
  }) {
    final dayName = AppConstants.weekdayFullLabels[now.weekday] ?? '';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return 'Current time: $timeStr on $dayName, '
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}. '
        "Today's progress: $todayCompletedCount/$todayActivityCount activities completed.";
  }

  /// Trim conversation history to stay within token budget.
  /// Keep first user message + last N turns.
  List<ChatMessage> _trimMessages(List<ChatMessage> messages) {
    if (messages.length <= AppConstants.maxConversationTurns * 2) {
      return messages;
    }

    // Keep first message for context, then the most recent turns
    final maxMessages = AppConstants.maxConversationTurns * 2;
    final firstMessage = messages.first;
    final recentMessages = messages.sublist(messages.length - maxMessages + 1);

    return [firstMessage, ...recentMessages];
  }

  /// Parse tool call from LLM response text.
  /// Returns null if no tool call found.
  static ToolCallParsed? parseToolCall(String text) {
    final regex = RegExp(r'<tool_call>(.*?)</tool_call>', dotAll: true);
    final match = regex.firstMatch(text);
    if (match == null) return null;

    try {
      final json = jsonDecode(match.group(1)!.trim()) as Map<String, dynamic>;
      final name = json['name'] as String;
      final arguments =
          (json['arguments'] as Map<String, dynamic>?) ?? {};

      // Text before the tool call
      final textBefore = text.substring(0, match.start).trim();

      return ToolCallParsed(
        name: name,
        arguments: arguments,
        textBefore: textBefore,
        fullMatch: match.group(0)!,
      );
    } catch (_) {
      return null;
    }
  }
}

class ToolCallParsed {
  final String name;
  final Map<String, dynamic> arguments;
  final String textBefore;
  final String fullMatch;

  const ToolCallParsed({
    required this.name,
    required this.arguments,
    required this.textBefore,
    required this.fullMatch,
  });
}
