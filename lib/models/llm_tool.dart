class LlmTool {
  final String name;
  final String description;
  final Map<String, LlmToolParam> parameters;
  final bool requiresConfirmation;

  const LlmTool({
    required this.name,
    required this.description,
    required this.parameters,
    this.requiresConfirmation = false,
  });

  Map<String, dynamic> toSchemaJson() {
    final props = <String, dynamic>{};
    final required = <String>[];

    for (final entry in parameters.entries) {
      final param = entry.value;
      final prop = <String, dynamic>{
        'type': param.type,
        'description': param.description,
      };
      if (param.enumValues != null) {
        prop['enum'] = param.enumValues;
      }
      props[entry.key] = prop;
      if (param.required) {
        required.add(entry.key);
      }
    }

    return {
      'name': name,
      'description': description,
      'parameters': {
        'type': 'object',
        'properties': props,
        if (required.isNotEmpty) 'required': required,
      },
    };
  }
}

class LlmToolParam {
  final String type;
  final String description;
  final bool required;
  final List<String>? enumValues;

  const LlmToolParam({
    required this.type,
    required this.description,
    this.required = false,
    this.enumValues,
  });
}
