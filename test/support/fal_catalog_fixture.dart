/// Mirrors the separate submit, status and final result schemas in fal's queue.
Map<String, dynamic> falCatalogFixture({
  required String id,
  required String category,
  required Map<String, Object?> inputs,
  required List<String> requiredInputs,
  required Map<String, Object?> outputs,
}) => {
  'endpoint_id': id,
  'metadata': {'status': 'active', 'category': category, 'display_name': id},
  'openapi': {
    'paths': {
      '/canonical/submit': {
        'post': {
          'requestBody': {
            'content': {
              'application/json': {
                'schema': {r'$ref': '#/components/schemas/Input'},
              },
            },
          },
        },
      },
      '/canonical/requests/{request_id}/status': {
        'get': {
          'responses': {
            '200': {
              'content': {
                'application/json': {
                  'schema': {
                    'properties': {
                      'status': {'type': 'string'},
                    },
                  },
                },
              },
            },
          },
        },
      },
      '/canonical/requests/{request_id}': {
        'get': {
          'responses': {
            '200': {
              'content': {
                'application/json': {
                  'schema': {'properties': outputs},
                },
              },
            },
          },
        },
      },
    },
    'components': {
      'schemas': {
        'Input': {
          'type': 'object',
          'properties': inputs,
          'required': requiredInputs,
        },
        'File': {
          'type': 'object',
          'properties': {
            'url': {'type': 'string'},
          },
        },
      },
    },
  },
};

const falFileFixture = {r'$ref': '#/components/schemas/File'};
