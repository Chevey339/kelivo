/// One image viewer with independently gated conversation and workspace inputs.
abstract final class ViewImageTool {
  static const name = 'view_image';
  static const historyDescription =
      'Images already included in messages can be inspected directly; do not call this tool for them. '
      'Use image_id only to retrieve a conversation image that is missing from the current context. '
      'Call with no image selected to list available conversation images; pass next_offset as offset to list more. '
      'When using image_id, do not also supply a file path.';

  /// Adds conversation lookup to the existing file viewer, when available.
  static Map<String, dynamic> withHistory([
    Map<String, dynamic>? fileDefinition,
  ]) {
    final function =
        (fileDefinition?['function'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final parameters =
        (function['parameters'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return {
      'type': 'function',
      'function': <String, dynamic>{
        ...function,
        'name': name,
        'strict': false,
        'description': [
          if (function['description'] case final String description)
            description,
          historyDescription,
        ].join(' '),
        'parameters': <String, dynamic>{
          ...parameters,
          'type': 'object',
          'properties': <String, dynamic>{
            ...?(parameters['properties'] as Map?)?.cast<String, dynamic>(),
            'image_id': {
              'type': 'string',
              'pattern': r'^img_[0-9a-f]{20}$',
              'description':
                  'Copy the exact img_ identifier from an omitted-image placeholder or image listing. Never invent an ID such as img_1. If the ID is unknown, call with no image selected to list available images first.',
            },
            'offset': {
              'type': 'integer',
              'minimum': 0,
              'description':
                  'Offset for listing conversation images; default 0.',
            },
          },
          'required': <String>[],
          'additionalProperties': false,
        },
      },
    };
  }

  static bool supportsFiles(Map tool) => _hasParameter(tool, 'path');

  static bool supportsHistory(Map tool) => _hasParameter(tool, 'image_id');

  static bool _hasParameter(Map tool, String parameter) {
    final function = tool['function'] is Map ? tool['function'] as Map : tool;
    final parameters = function['parameters'] ?? function['input_schema'];
    return function['name'] == name &&
        parameters is Map &&
        parameters['properties'] is Map &&
        (parameters['properties'] as Map).containsKey(parameter);
  }

  /// Remove conversation lookup from any provider's function declaration.
  /// A file viewer remains usable when conversation recall is disabled/empty.
  static Map<String, dynamic>? withoutHistory(Map<String, dynamic> tool) {
    final wrapped = tool['function'] is Map;
    final function = wrapped ? tool['function'] as Map : tool;
    if (function['name'] != name) return tool;
    if (!supportsFiles(tool)) return null;
    final schemaKey = function.containsKey('input_schema')
        ? 'input_schema'
        : 'parameters';
    final parameters = function[schemaKey] as Map;
    final properties = parameters['properties'] as Map;
    if (!properties.containsKey('image_id')) return tool;
    final fileFunction = <String, dynamic>{
      ...function.cast<String, dynamic>(),
      if (function['description'] case final String description)
        'description': description.replaceAll(historyDescription, '').trim(),
      schemaKey: <String, dynamic>{
        ...parameters.cast<String, dynamic>(),
        'properties': <String, dynamic>{
          for (final entry in properties.entries)
            if (entry.key != 'image_id' && entry.key != 'offset')
              entry.key as String: entry.value,
        },
        'required': ['path'],
      },
    };
    return wrapped ? {...tool, 'function': fileFunction} : fileFunction;
  }
}
