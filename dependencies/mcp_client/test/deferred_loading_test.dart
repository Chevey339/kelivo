import 'package:mcp_client/mcp_client.dart';
import 'package:test/test.dart';

import 'mock_transport.dart';

void main() {
  group('Deferred Tool Loading Tests', () {
    group('ToolMetadata', () {
      test('creates with required fields', () {
        const metadata = ToolMetadata(
          name: 'calculator',
          description: 'Perform calculations',
        );

        expect(metadata.name, equals('calculator'));
        expect(metadata.description, equals('Perform calculations'));
      });

      test('fromTool creates from Tool object', () {
        const tool = Tool(
          name: 'search',
          description: 'Search the web',
          inputSchema: {
            'type': 'object',
            'properties': {
              'query': {'type': 'string'},
            },
            'required': ['query'],
          },
        );

        final metadata = ToolMetadata.fromTool(tool);

        expect(metadata.name, equals('search'));
        expect(metadata.description, equals('Search the web'));
      });

      test('Tool.fromJson handles missing description', () {
        final tool = Tool.fromJson({
          'name': 'simple-tool',
          'inputSchema': {'type': 'object'},
        });

        expect(tool.name, equals('simple-tool'));
        expect(tool.description, equals(''));
      });

      test('fromMap creates from Map', () {
        final map = {
          'name': 'weather',
          'description': 'Get weather information',
          'inputSchema': {'type': 'object'},
        };

        final metadata = ToolMetadata.fromMap(map);

        expect(metadata.name, equals('weather'));
        expect(metadata.description, equals('Get weather information'));
      });

      test('fromMap handles missing description', () {
        final map = {'name': 'simple-tool'};

        final metadata = ToolMetadata.fromMap(map);

        expect(metadata.name, equals('simple-tool'));
        expect(metadata.description, equals(''));
      });

      test('toJson returns lightweight representation', () {
        const metadata = ToolMetadata(
          name: 'calculator',
          description: 'Perform calculations',
        );

        final json = metadata.toJson();

        expect(
          json,
          equals({'name': 'calculator', 'description': 'Perform calculations'}),
        );
        expect(json.containsKey('inputSchema'), isFalse);
      });

      test('equality works correctly', () {
        const metadata1 = ToolMetadata(
          name: 'calculator',
          description: 'Perform calculations',
        );
        const metadata2 = ToolMetadata(
          name: 'calculator',
          description: 'Perform calculations',
        );
        const metadata3 = ToolMetadata(
          name: 'different',
          description: 'Perform calculations',
        );

        expect(metadata1, equals(metadata2));
        expect(metadata1, isNot(equals(metadata3)));
        expect(metadata1.hashCode, equals(metadata2.hashCode));
      });

      test('toString returns readable representation', () {
        const metadata = ToolMetadata(
          name: 'calculator',
          description: 'Perform calculations',
        );

        expect(
          metadata.toString(),
          equals(
            'ToolMetadata(name: calculator, description: Perform calculations)',
          ),
        );
      });
    });

    group('ToolRegistry', () {
      late ToolRegistry registry;

      setUp(() {
        registry = ToolRegistry();
      });

      test('starts uninitialized', () {
        expect(registry.isInitialized, isFalse);
        expect(registry.count, equals(0));
        expect(registry.toolNames, isEmpty);
      });

      test('cacheFromTools initializes registry', () {
        final tools = [
          const Tool(
            name: 'calculator',
            description: 'Perform calculations',
            inputSchema: {'type': 'object'},
          ),
          const Tool(
            name: 'search',
            description: 'Search the web',
            inputSchema: {'type': 'object'},
          ),
        ];

        registry.cacheFromTools(tools);

        expect(registry.isInitialized, isTrue);
        expect(registry.count, equals(2));
        expect(registry.toolNames, containsAll(['calculator', 'search']));
      });

      test('cacheFromMaps initializes registry', () {
        final tools = [
          {
            'name': 'calculator',
            'description': 'Perform calculations',
            'inputSchema': {'type': 'object'},
          },
          {
            'name': 'search',
            'description': 'Search the web',
            'inputSchema': {'type': 'object'},
          },
        ];

        registry.cacheFromMaps(tools);

        expect(registry.isInitialized, isTrue);
        expect(registry.count, equals(2));
        expect(registry.toolNames, containsAll(['calculator', 'search']));
      });

      test('getAllMetadata returns lightweight metadata list', () {
        final tools = [
          const Tool(
            name: 'calculator',
            description: 'Perform calculations',
            inputSchema: {
              'type': 'object',
              'properties': {'a': {}, 'b': {}},
            },
          ),
        ];

        registry.cacheFromTools(tools);

        final metadata = registry.getAllMetadata();

        expect(metadata.length, equals(1));
        expect(metadata[0].name, equals('calculator'));
        expect(metadata[0].description, equals('Perform calculations'));
      });

      test('getMetadata returns specific tool metadata', () {
        final tools = [
          const Tool(
            name: 'calculator',
            description: 'Perform calculations',
            inputSchema: {'type': 'object'},
          ),
        ];

        registry.cacheFromTools(tools);

        final metadata = registry.getMetadata('calculator');
        final notFound = registry.getMetadata('nonexistent');

        expect(metadata, isNotNull);
        expect(metadata!.name, equals('calculator'));
        expect(notFound, isNull);
      });

      test('getSchema returns full tool schema', () {
        final tools = [
          const Tool(
            name: 'calculator',
            description: 'Perform calculations',
            inputSchema: {
              'type': 'object',
              'properties': {
                'operation': {'type': 'string'},
                'a': {'type': 'number'},
                'b': {'type': 'number'},
              },
              'required': ['operation', 'a', 'b'],
            },
          ),
        ];

        registry.cacheFromTools(tools);

        final schema = registry.getSchema('calculator');
        final notFound = registry.getSchema('nonexistent');

        expect(schema, isNotNull);
        expect(schema!['name'], equals('calculator'));
        expect(schema['inputSchema'], isNotNull);
        expect(schema['inputSchema']['properties'], isNotNull);
        expect(notFound, isNull);
      });

      test('hasTool checks tool existence', () {
        final tools = [
          const Tool(
            name: 'calculator',
            description: 'Perform calculations',
            inputSchema: {'type': 'object'},
          ),
        ];

        registry.cacheFromTools(tools);

        expect(registry.hasTool('calculator'), isTrue);
        expect(registry.hasTool('nonexistent'), isFalse);
      });

      test('invalidateAll clears registry', () {
        final tools = [
          const Tool(
            name: 'calculator',
            description: 'Perform calculations',
            inputSchema: {'type': 'object'},
          ),
        ];

        registry.cacheFromTools(tools);
        expect(registry.isInitialized, isTrue);
        expect(registry.count, equals(1));

        registry.invalidateAll();

        expect(registry.isInitialized, isFalse);
        expect(registry.count, equals(0));
        expect(registry.getAllMetadata(), isEmpty);
        expect(registry.getMetadata('calculator'), isNull);
        expect(registry.getSchema('calculator'), isNull);
      });

      test('caching again replaces existing data', () {
        final tools1 = [
          const Tool(
            name: 'tool1',
            description: 'First tool',
            inputSchema: {'type': 'object'},
          ),
        ];

        final tools2 = [
          const Tool(
            name: 'tool2',
            description: 'Second tool',
            inputSchema: {'type': 'object'},
          ),
          const Tool(
            name: 'tool3',
            description: 'Third tool',
            inputSchema: {'type': 'object'},
          ),
        ];

        registry.cacheFromTools(tools1);
        expect(registry.count, equals(1));
        expect(registry.hasTool('tool1'), isTrue);

        registry.cacheFromTools(tools2);
        expect(registry.count, equals(2));
        expect(registry.hasTool('tool1'), isFalse);
        expect(registry.hasTool('tool2'), isTrue);
        expect(registry.hasTool('tool3'), isTrue);
      });
    });

    group('ClientToolMetadataExtension', () {
      late Client client;
      late MockTransport mockTransport;

      setUp(() {
        final config = McpClient.simpleConfig(
          name: 'Test Client',
          version: '1.0.0',
          enableDebugLogging: false,
        );
        client = McpClient.createClient(config);
        mockTransport = MockTransport();
      });

      tearDown(() {
        client.disconnect();
      });

      test('listToolsMetadata fetches tools and returns metadata', () async {
        // Setup mock responses
        mockTransport.queueResponse({
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 1,
          'result': {
            'protocolVersion': McpProtocol.v2025_03_26,
            'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
            'capabilities': {
              'tools': {'listChanged': true},
            },
          },
        });

        mockTransport.queueResponse({
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 2,
          'result': {
            'tools': [
              {
                'name': 'calculator',
                'description': 'Perform basic calculations',
                'inputSchema': {
                  'type': 'object',
                  'properties': {
                    'operation': {'type': 'string'},
                    'a': {'type': 'number'},
                    'b': {'type': 'number'},
                  },
                  'required': ['operation', 'a', 'b'],
                },
              },
              {
                'name': 'search',
                'description': 'Search the web',
                'inputSchema': {
                  'type': 'object',
                  'properties': {
                    'query': {'type': 'string'},
                  },
                  'required': ['query'],
                },
              },
            ],
          },
        });

        await client.connect(mockTransport);

        final registry = ToolRegistry();
        final metadata = await client.listToolsMetadata(registry);

        // Verify metadata returned
        expect(metadata.length, equals(2));
        expect(metadata[0].name, equals('calculator'));
        expect(metadata[0].description, equals('Perform basic calculations'));
        expect(metadata[1].name, equals('search'));
        expect(metadata[1].description, equals('Search the web'));

        // Verify registry was populated
        expect(registry.isInitialized, isTrue);
        expect(registry.count, equals(2));
        expect(registry.hasTool('calculator'), isTrue);
        expect(registry.hasTool('search'), isTrue);

        // Verify full schemas are available
        final calcSchema = registry.getSchema('calculator');
        expect(calcSchema, isNotNull);
        expect(
          calcSchema!['inputSchema']['properties']['operation'],
          isNotNull,
        );
      });

      test('listToolsMetadata with empty tools list', () async {
        mockTransport.queueResponse({
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 1,
          'result': {
            'protocolVersion': McpProtocol.v2025_03_26,
            'serverInfo': {'name': 'Mock Server', 'version': '1.0.0'},
            'capabilities': {'tools': {}},
          },
        });

        mockTransport.queueResponse({
          'jsonrpc': McpProtocol.jsonRpcVersion,
          'id': 2,
          'result': {'tools': []},
        });

        await client.connect(mockTransport);

        final registry = ToolRegistry();
        final metadata = await client.listToolsMetadata(registry);

        expect(metadata, isEmpty);
        expect(registry.isInitialized, isTrue);
        expect(registry.count, equals(0));
      });
    });

    group('Token Efficiency Verification', () {
      test('metadata JSON is smaller than full tool JSON', () {
        const tool = Tool(
          name: 'complex-tool',
          description: 'A tool with complex schema',
          inputSchema: {
            'type': 'object',
            'properties': {
              'param1': {'type': 'string', 'description': 'First parameter'},
              'param2': {'type': 'number', 'description': 'Second parameter'},
              'param3': {'type': 'boolean', 'description': 'Third parameter'},
              'param4': {
                'type': 'array',
                'items': {'type': 'string'},
                'description': 'Fourth parameter',
              },
              'param5': {
                'type': 'object',
                'properties': {
                  'nested1': {'type': 'string'},
                  'nested2': {'type': 'number'},
                },
                'description': 'Fifth parameter',
              },
            },
            'required': ['param1', 'param2'],
          },
          supportsProgress: true,
          supportsCancellation: true,
          metadata: {'version': '1.0', 'author': 'test'},
        );

        final fullJson = tool.toJson();
        final metadata = ToolMetadata.fromTool(tool);
        final metadataJson = metadata.toJson();

        final fullSize = fullJson.toString().length;
        final metadataSize = metadataJson.toString().length;

        // Metadata should be significantly smaller
        expect(metadataSize, lessThan(fullSize));

        // Calculate reduction percentage
        final reduction = ((fullSize - metadataSize) / fullSize * 100).round();

        // Should achieve at least 50% reduction for complex tools
        expect(reduction, greaterThanOrEqualTo(50));
      });
    });
  });
}
