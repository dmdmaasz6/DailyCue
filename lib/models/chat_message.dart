enum ChatRole { user, assistant, system, toolCall, toolResult }

class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;
  final String? toolName;
  final Map<String, dynamic>? toolArgs;
  final bool? toolSuccess;

  /// Identifier linking a tool call to its result (used by OpenAI API).
  final String? toolCallId;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.toolName,
    this.toolArgs,
    this.toolSuccess,
    this.toolCallId,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? content,
    bool? toolSuccess,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      toolName: toolName,
      toolArgs: toolArgs,
      toolSuccess: toolSuccess ?? this.toolSuccess,
      toolCallId: toolCallId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      if (toolName != null) 'toolName': toolName,
      if (toolArgs != null) 'toolArgs': toolArgs,
      if (toolSuccess != null) 'toolSuccess': toolSuccess,
      if (toolCallId != null) 'toolCallId': toolCallId,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: ChatRole.values.byName(json['role'] as String),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      toolName: json['toolName'] as String?,
      toolArgs: json['toolArgs'] != null
          ? Map<String, dynamic>.from(json['toolArgs'] as Map)
          : null,
      toolSuccess: json['toolSuccess'] as bool?,
      toolCallId: json['toolCallId'] as String?,
    );
  }
}
