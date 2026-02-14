import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/llm_tool.dart';
import 'llm_backend.dart';
import 'prompt_builder.dart';

/// LLM backend that calls the OpenAI Chat Completions API.
class OpenAiBackend extends LlmBackend {
  final String apiKey;
  final String model;

  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  /// Currently running HTTP request (for cancellation).
  http.Client? _activeClient;

  OpenAiBackend({
    required this.apiKey,
    this.model = 'gpt-4o-mini',
  });

  @override
  Future<LlmGenerationResult> generate({
    required List<ChatMessage> messages,
    required List<LlmTool> tools,
    String? contextSnapshot,
  }) async {
    // Build system message
    final systemContent = StringBuffer(PromptBuilder.coreSystemPrompt);
    if (contextSnapshot != null) {
      systemContent.write('\n\n## Current Context\n');
      systemContent.write(contextSnapshot);
    }

    // Convert messages to OpenAI format
    final openAiMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemContent.toString()},
      ..._convertMessages(messages),
    ];

    // Convert tools to OpenAI function calling format
    final openAiTools = tools.map((t) {
      return {
        'type': 'function',
        'function': t.toSchemaJson(),
      };
    }).toList();

    // Build request body
    final body = <String, dynamic>{
      'model': model,
      'messages': openAiMessages,
      'temperature': 0.7,
      'max_tokens': 1024,
    };

    // Only include tools if available
    if (openAiTools.isNotEmpty) {
      body['tools'] = openAiTools;
      body['tool_choice'] = 'auto';
    }

    // Make HTTP request
    _activeClient = http.Client();
    try {
      final response = await _activeClient!.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        final errorBody = _tryParseJson(response.body);
        final errorMessage = errorBody?['error']?['message'] as String? ??
            'HTTP ${response.statusCode}';
        throw Exception('OpenAI API error: $errorMessage');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseResponse(json);
    } finally {
      _activeClient?.close();
      _activeClient = null;
    }
  }

  @override
  Future<void> stopGeneration() async {
    _activeClient?.close();
    _activeClient = null;
  }

  /// Convert internal ChatMessage list to OpenAI messages format.
  List<Map<String, dynamic>> _convertMessages(List<ChatMessage> messages) {
    final result = <Map<String, dynamic>>[];

    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];

      switch (msg.role) {
        case ChatRole.user:
          result.add({'role': 'user', 'content': msg.content});
          break;

        case ChatRole.assistant:
          result.add({'role': 'assistant', 'content': msg.content});
          break;

        case ChatRole.toolCall:
          final callId = msg.toolCallId ?? 'call_${msg.id}';
          result.add({
            'role': 'assistant',
            'content': null,
            'tool_calls': [
              {
                'id': callId,
                'type': 'function',
                'function': {
                  'name': msg.toolName ?? '',
                  'arguments': jsonEncode(msg.toolArgs ?? {}),
                },
              },
            ],
          });
          break;

        case ChatRole.toolResult:
          // Find the matching tool call ID
          final callId = msg.toolCallId ?? _findPrecedingToolCallId(messages, i);
          result.add({
            'role': 'tool',
            'tool_call_id': callId,
            'content': msg.content,
          });
          break;

        case ChatRole.system:
          // System message already added at the start
          break;
      }
    }

    return result;
  }

  /// Walk backwards from index to find the preceding toolCall message's ID.
  String _findPrecedingToolCallId(List<ChatMessage> messages, int fromIndex) {
    for (int j = fromIndex - 1; j >= 0; j--) {
      if (messages[j].role == ChatRole.toolCall) {
        return messages[j].toolCallId ?? 'call_${messages[j].id}';
      }
    }
    return 'call_unknown';
  }

  /// Parse OpenAI Chat Completions response into LlmGenerationResult.
  LlmGenerationResult _parseResponse(Map<String, dynamic> json) {
    final choices = json['choices'] as List<dynamic>;
    if (choices.isEmpty) {
      return const LlmGenerationResult(textContent: 'No response generated.');
    }

    final choice = choices[0] as Map<String, dynamic>;
    final message = choice['message'] as Map<String, dynamic>;

    // Check for tool calls
    final toolCalls = message['tool_calls'] as List<dynamic>?;

    if (toolCalls != null && toolCalls.isNotEmpty) {
      final tc = toolCalls[0] as Map<String, dynamic>;
      final function_ = tc['function'] as Map<String, dynamic>;
      final callId = tc['id'] as String;
      final name = function_['name'] as String;

      // Arguments come as a JSON string from OpenAI
      Map<String, dynamic> arguments;
      try {
        arguments = jsonDecode(function_['arguments'] as String)
            as Map<String, dynamic>;
      } catch (_) {
        arguments = {};
      }

      // Any text content alongside the tool call
      final textContent = message['content'] as String? ?? '';

      return LlmGenerationResult(
        textContent: '',
        toolCall: LlmToolCallResult(
          id: callId,
          name: name,
          arguments: arguments,
          textBefore: textContent,
        ),
      );
    }

    // Plain text response
    final content = message['content'] as String? ?? '';
    return LlmGenerationResult(textContent: content);
  }

  Map<String, dynamic>? _tryParseJson(String text) {
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
