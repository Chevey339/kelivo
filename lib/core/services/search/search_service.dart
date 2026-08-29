import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../network/dio_http_client.dart';
import 'search_api_key_rotator.dart';
// Import statements for service implementations
import 'providers/bing_search_service.dart';
import 'providers/tavily_search_service.dart';
import 'providers/exa_search_service.dart';
import 'providers/zhipu_search_service.dart';
import 'providers/searxng_search_service.dart';
import 'providers/linkup_search_service.dart';
import 'providers/brave_search_service.dart';
import 'providers/metaso_search_service.dart';
import 'providers/ollama_search_service.dart';
import 'providers/jina_search_service.dart';
import 'providers/bocha_search_service.dart';
import 'providers/perplexity_search_service.dart';
import 'providers/duckduckgo_search_service.dart';
import 'providers/serper_search_service.dart';
import 'providers/grok_search_service.dart';
import 'providers/querit_search_service.dart';
import 'providers/stepfun_search_service.dart';
import 'providers/firecrawl_search_service.dart';
import 'providers/tinyfish_search_service.dart';
import 'providers/anysearch_search_service.dart';
import 'providers/doubao_search_service.dart';
import 'providers/kelivo_search_service.dart';

// Base interface for all search services
abstract class SearchService<T extends SearchServiceOptions> {
  SearchService({this.client});

  final http.Client? client;

  String get name;

  Widget description(BuildContext context);

  Future<SearchResult> search({
    required String query,
    required SearchCommonOptions commonOptions,
    required T serviceOptions,
  });

  /// Runs search traffic through the app's logged HTTP client by default.
  /// Tests can inject a client without transferring ownership to the service.
  Future<R> withHttpClient<R>(
    Future<R> Function(http.Client client) request,
  ) async {
    final ownsClient = client == null;
    final effectiveClient = client ?? DioHttpClient();
    try {
      return await request(effectiveClient);
    } finally {
      if (ownsClient) effectiveClient.close();
    }
  }

  // Factory method to get service instance based on options type
  static SearchService getService(SearchServiceOptions options) {
    switch (options) {
      case BingLocalOptions _:
        return BingSearchService() as SearchService;
      case TavilyOptions _:
        return TavilySearchService() as SearchService;
      case ExaOptions _:
        return ExaSearchService() as SearchService;
      case ZhipuOptions _:
        return ZhipuSearchService() as SearchService;
      case SearXNGOptions _:
        return SearXNGSearchService() as SearchService;
      case LinkUpOptions _:
        return LinkUpSearchService() as SearchService;
      case BraveOptions _:
        return BraveSearchService() as SearchService;
      case MetasoOptions _:
        return MetasoSearchService() as SearchService;
      case OllamaOptions _:
        return OllamaSearchService() as SearchService;
      case JinaOptions _:
        return JinaSearchService() as SearchService;
      case BochaOptions _:
        return BochaSearchService() as SearchService;
      case PerplexityOptions _:
        return PerplexitySearchService() as SearchService;
      case DuckDuckGoOptions _:
        return DuckDuckGoSearchService() as SearchService;
      case SerperOptions _:
        return SerperSearchService() as SearchService;
      case GrokOptions _:
        return GrokSearchService() as SearchService;
      case QueritOptions _:
        return QueritSearchService() as SearchService;
      case StepFunOptions _:
        return StepFunSearchService() as SearchService;
      case FirecrawlOptions _:
        return FirecrawlSearchService() as SearchService;
      case TinyFishOptions _:
        return TinyFishSearchService() as SearchService;
      case AnySearchOptions _:
        return AnySearchSearchService() as SearchService;
      case DoubaoOptions _:
        return DoubaoSearchService() as SearchService;
      case KelivoOptions _:
        return KelivoSearchService() as SearchService;
      default:
        return BingSearchService() as SearchService;
    }
  }
}

// Search result data structure
class SearchResult {
  final String? answer;
  final List<SearchResultItem> items;

  SearchResult({this.answer, required this.items});

  Map<String, dynamic> toJson() => {
    if (answer != null) 'answer': answer,
    'items': items.map((e) => e.toJson()).toList(),
  };

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
    answer: json['answer'],
    items: (json['items'] as List)
        .map((e) => SearchResultItem.fromJson(e))
        .toList(),
  );
}

class SearchResultItem {
  final String title;
  final String url;
  final String text;
  String? id;
  int? index;

  SearchResultItem({
    required this.title,
    required this.url,
    required this.text,
    this.id,
    this.index,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'text': text,
    if (id != null) 'id': id,
    if (index != null) 'index': index,
  };

  factory SearchResultItem.fromJson(Map<String, dynamic> json) =>
      SearchResultItem(
        title: json['title'],
        url: json['url'],
        text: json['text'],
        id: json['id'],
        index: json['index'],
      );
}

// Common search options
class SearchCommonOptions {
  final int resultSize;
  final int timeout;

  const SearchCommonOptions({this.resultSize = 10, this.timeout = 5000});

  Map<String, dynamic> toJson() => {
    'resultSize': resultSize,
    'timeout': timeout,
  };

  factory SearchCommonOptions.fromJson(Map<String, dynamic> json) =>
      SearchCommonOptions(
        resultSize: json['resultSize'] ?? 10,
        timeout: json['timeout'] ?? 5000,
      );
}

// Base class for service-specific options
abstract class SearchServiceOptions {
  final String id;

  /// Additional API keys that join [apiKey] in the round-robin rotation
  /// pool. Only meaningful for key-based services; stays empty otherwise.
  final List<String> extraApiKeys;

  const SearchServiceOptions({required this.id, this.extraApiKeys = const []});

  Map<String, dynamic> toJson();

  /// Reads the optional `apiKeys` list persisted alongside the primary key.
  static List<String> parseExtraApiKeys(Map<String, dynamic> json) =>
      (json['apiKeys'] as List?)
          ?.map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList() ??
      const [];

  /// Resolves the API key for the next request, rotating through
  /// [extraApiKeys] (round-robin) when any are configured.
  String effectiveApiKey(String primary) =>
      SearchApiKeyRotator.instance.select(id, primary, extraApiKeys);

  /// The primary API key for key-based services; empty for the rest.
  String get primaryApiKey => (toJson()['apiKey'] as String?) ?? '';

  static SearchServiceOptions fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'bing_local':
        return BingLocalOptions.fromJson(json);
      case 'tavily':
        return TavilyOptions.fromJson(json);
      case 'exa':
        return ExaOptions.fromJson(json);
      case 'zhipu':
        return ZhipuOptions.fromJson(json);
      case 'searxng':
        return SearXNGOptions.fromJson(json);
      case 'linkup':
        return LinkUpOptions.fromJson(json);
      case 'brave':
        return BraveOptions.fromJson(json);
      case 'metaso':
        return MetasoOptions.fromJson(json);
      case 'ollama':
        return OllamaOptions.fromJson(json);
      case 'jina':
        return JinaOptions.fromJson(json);
      case 'bocha':
        return BochaOptions.fromJson(json);
      case 'duckduckgo':
        return DuckDuckGoOptions.fromJson(json);
      case 'perplexity':
        return PerplexityOptions.fromJson(json);
      case 'serper':
        return SerperOptions.fromJson(json);
      case 'grok':
        return GrokOptions.fromJson(json);
      case 'querit':
        return QueritOptions.fromJson(json);
      case 'stepfun':
      case 'step':
        return StepFunOptions.fromJson(json);
      case 'firecrawl':
        return FirecrawlOptions.fromJson(json);
      case 'tinyfish':
        return TinyFishOptions.fromJson(json);
      case 'anysearch':
        return AnySearchOptions.fromJson(json);
      case 'doubao':
        return DoubaoOptions.fromJson(json);
      case 'kelivo':
        return KelivoOptions.fromJson(json);
      default:
        return BingLocalOptions(id: json['id']);
    }
  }

  static final SearchServiceOptions defaultOption = BingLocalOptions(
    id: 'default',
  );
}

// Service-specific option classes
class BingLocalOptions extends SearchServiceOptions {
  final String acceptLanguage;

  BingLocalOptions({required super.id, this.acceptLanguage = 'en-US,en;q=0.9'});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'bing_local',
    'id': id,
    'acceptLanguage': acceptLanguage,
  };

  factory BingLocalOptions.fromJson(Map<String, dynamic> json) =>
      BingLocalOptions(
        id: json['id'],
        acceptLanguage: json['acceptLanguage'] ?? 'en-US,en;q=0.9',
      );
}

class TavilyOptions extends SearchServiceOptions {
  static const String defaultUrl = 'https://api.tavily.com/search';

  final String apiKey;
  final String url;

  TavilyOptions({
    required super.id,
    required this.apiKey,
    this.url = '',
    super.extraApiKeys,
  });

  String get resolvedUrl {
    final trimmed = url.trim();
    return trimmed.isEmpty ? defaultUrl : trimmed;
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'tavily',
    'id': id,
    'apiKey': apiKey,
    'url': url.trim(),
    if (extraApiKeys.isNotEmpty) 'apiKeys': extraApiKeys,
  };

  factory TavilyOptions.fromJson(Map<String, dynamic> json) => TavilyOptions(
    id: json['id'],
    apiKey: json['apiKey'],
    url: json['url'] ?? '',
    extraApiKeys: SearchServiceOptions.parseExtraApiKeys(json),
  );
}

class ExaOptions extends SearchServiceOptions {
  static const String defaultUrl = 'https://api.exa.ai/search';

  final String apiKey;
  final String url;

  ExaOptions({
    required super.id,
    required this.apiKey,
    this.url = '',
    super.extraApiKeys,
  });

  String get resolvedUrl {
    final trimmed = url.trim();
    return trimmed.isEmpty ? defaultUrl : trimmed;
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'exa',
    'id': id,
    'apiKey': apiKey,
    'url': url.trim(),
    if (extraApiKeys.isNotEmpty) 'apiKeys': extraApiKeys,
  };

  factory ExaOptions.fromJson(Map<String, dynamic> json) => ExaOptions(
    id: json['id'],
    apiKey: json['apiKey'],
    url: json['url'] ?? '',
    extraApiKeys: SearchServiceOptions.parseExtraApiKeys(json),
  );
}

class ZhipuOptions extends SearchServiceOptions {
  final String apiKey;

  ZhipuOptions({required super.id, required this.apiKey, super.extraApiKeys});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'zhipu',
    'id': id,
    'apiKey': apiKey,
    if (extraApiKeys.isNotEmpty) 'apiKeys': extraApiKeys,
  };

  factory ZhipuOptions.fromJson(Map<String, dynamic> json) => ZhipuOptions(
    id: json['id'],
    apiKey: json['apiKey'],
    extraApiKeys: SearchServiceOptions.parseExtraApiKeys(json),
  );
}

class SearXNGOptions extends SearchServiceOptions {
  final String url;
  final String engines;
  final String language;
  final String username;
  final String password;

  SearXNGOptions({
    required super.id,
    required this.url,
    this.engines = '',
    this.language = '',
    this.username = '',
    this.password = '',
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'searxng',
    'id': id,
    'url': url,
    'engines': engines,
    'language': language,
    'username': username,
    'password': password,
  };

  factory SearXNGOptions.fromJson(Map<String, dynamic> json) => SearXNGOptions(
    id: json['id'],
    url: json['url'],
    engines: json['engines'] ?? '',
    language: json['language'] ?? '',
    username: json['username'] ?? '',
    password: json['password'] ?? '',
  );
}

class LinkUpOptions extends SearchServiceOptions {
  final String apiKey;

  LinkUpOptions({required super.id, required this.apiKey, super.extraApiKeys});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'linkup',
    'id': id,
    'apiKey': apiKey,
    if (extraApiKeys.isNotEmpty) 'apiKeys': extraApiKeys,
  };

  factory LinkUpOptions.fromJson(Map<String, dynamic> json) => LinkUpOptions(
    id: json['id'],
    apiKey: json['apiKey'],
    extraApiKeys: SearchServiceOptions.parseExtraApiKeys(json),
  );
}

class BraveOptions extends SearchServiceOptions {
  final String apiKey;

  BraveOptions({required super.id, required this.apiKey, super.extraApiKeys});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'brave',
    'id': id,
    'apiKey': apiKey,
    if (extraApiKeys.isNotEmpty) 'apiKeys': extraApiKeys,
  };

  factory BraveOptions.fromJson(Map<String, dynamic> json) => BraveOptions(
    id: json['id'],
    apiKey: json['apiKey'],
    extraApiKeys: SearchServiceOptions.parseExtraApiKeys(json),
  );
}

class MetasoOptions extends SearchServiceOptions {
  final String apiKey;

  MetasoOptions({required super.id, required this.apiKey, super.extraApiKeys});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'metaso',
    'id': id,
    'apiKey': apiKey,
    if (extraApiKeys.isNotEmpty) 'apiKeys': extraApiKeys,
  };

  factory MetasoOptions.fromJson(Map<String, dynamic> json) => MetasoOptions(
    id: json['id'],
    apiKey: json['apiKey'],
    extraApiKeys: SearchServiceOptions.parseExtraApiKeys(json),
  );
}

class OllamaOptions extends SearchServiceOptions {
  final String apiKey;

  OllamaOptions({required super.id, required this.apiKey, super.extraApiKeys});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'ollama',
    'id': id,
    'apiKey': apiKey,
    if (extraApiKeys.isNotEmpty) 'apiKeys': extraApiKeys,
  };

  factory OllamaOptions.fromJson(Map<String, dynamic> json) => OllamaOptions(
    id: json['id'],
    apiKey: json['apiKey'],
    extraApiKeys: SearchServiceOptions.parseExtraApiKeys(json),
  );
}

class JinaOptions extends SearchServiceOptions {
  final String apiKey;

  JinaOptions({required super.id, required this.apiKey, super.extraApiKeys});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'jina',
    'id': id,
    'apiKey': apiKey,
    if (extraApiKeys.isNotEmpty) 'apiKeys': extraApiKeys,
  };

  factory JinaOptions.fromJson(Map<String, dynamic> json) => JinaOptions(
    id: json['id'],
    apiKey: json['apiKey'],
    extraApiKeys: SearchServiceOptions.parseExtraApiKeys(json),
  );
}

class DuckDuckGoOptions extends SearchServiceOptions {
  final String region;

  DuckDuckGoOptions({required super.id, this.region = 'us-en'});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'duckduckgo',
    'id': id,
    'region': region,
  };

  factory DuckDuckGoOptions.fromJson(Map<String, dynamic> json) =>
      DuckDuckGoOptions(id: json['id'], region: json['region'] ?? 'us-en');
}

class PerplexityOptions extends SearchServiceOptions {
  final String apiKey;
  final String? country; // ISO 3166-1 alpha-2
  final List<String>? searchDomainFilter; // domains/URLs
  final int? maxTokensPerPage; // default 1024

  PerplexityOptions({
    required super.id,
    required this.apiKey,
    this.country,
    this.searchDomainFilter,
    this.maxTokensPerPage,
    super.extraApiKeys,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'perplexity',
    'id': id,
    'apiKey': apiKey,
    if (country != null) 'country': country,
    if (searchDomainFilter != null) 'searchDomainFilter': searchDomainFilter,
    if (maxTokensPerPage != null) 'maxTokensPerPage': maxTokensPerPage,
    if (extraApiKeys.isNotEmpty) 'apiKeys': extraApiKeys,
  };

  factory PerplexityOptions.fromJson(Map<String, dynamic> json) =>
      PerplexityOptions(
        id: json['id'],
        apiKey: json['apiKey'],
        country: json['country'],
        searchDomainFilter: (json['searchDomainFilter'] as List?)
            ?.map((e) => e.toString())
            .toList(),
        maxTokensPerPage: json['maxTokensPerPage'],
        extraApiKeys: SearchServiceOptions.parseExtraApiKeys(json),
      );
}

class BochaOptions extends SearchServiceOptions {
  final String apiKey;
  // Optional parameters supported by Bocha API
  final String? freshness; // e.g., 'noLimit', 'week', 'month', etc.
  final bool summary; // whether to include textual summary
  final String? include; // e.g., 'qq.com|m.163.com'
  final String? exclude; // e.g., 'qq.com|m.163.com'

  BochaOptions({
    required super.id,
    required this.apiKey,
    this.freshness,
    this.summary = true,
    this.include,
    this.exclude,
    super.extraApiKeys,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'bocha',
    'id': id,
    'apiKey': apiKey,
    if (freshness != null) 'freshness': freshness,
    'summary': summary,
    if (include != null) 'include': include,
    if (exclude != null) 'exclude': exclude,
    if (extraApiKeys.isNotEmpty) 'apiKeys': extraApiKeys,
  };

  factory BochaOptions.fromJson(Map<String, dynamic> json) => BochaOptions(
    id: json['id'],
    apiKey: json['apiKey'],
    freshness: json['freshness'],
    summary: (json['summary'] ?? true) as bool,
    include: json['include'],
    exclude: json['exclude'],
    extraApiKeys: SearchServiceOptions.parseExtraApiKeys(json),
  );
}

class SerperOptions extends SearchServiceOptions {
  final String apiKey;
  final String gl;
  final String hl;
  final String tbs;
  final int page;

  SerperOptions({
    required super.id,
    required this.apiKey,
    this.gl = '',
    this.hl = '',
    this.tbs = '',
    this.page = 1,
    super.extraApiKeys,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'serper',
    'id': id,
    'apiKey': apiKey,
    'gl': gl.trim(),
    'hl': hl.trim(),
    'tbs': tbs.trim(),
    'page': page,
    if (extraApiKeys.isNotEmpty) 'apiKeys': extraApiKeys,
  };

  factory SerperOptions.fromJson(Map<String, dynamic> json) => SerperOptions(
    id: json['id'],
    apiKey: json['apiKey'],
    gl: json['gl'] ?? '',
    hl: json['hl'] ?? '',
    tbs: json['tbs'] ?? '',
    page: json['page'] ?? 1,
    extraApiKeys: SearchServiceOptions.parseExtraApiKeys(json),
  );
}

class GrokOptions extends SearchServiceOptions {
  static const String defaultUrl = 'https://api.x.ai/v1/responses';
  static const String defaultModel = 'grok-4.5';
  static const String defaultReasoningEffort = 'low';
  static const String defaultSystemPrompt =
      "You are a helpful search assistant. Search the web to find accurate and up-to-date information for the user's query. Provide a comprehensive answer with citations.";

  final String apiKey;
  final String model;
  final String reasoningEffort;
  final String customUrl;
  final String systemPrompt;

  GrokOptions({
    required super.id,
    required this.apiKey,
    this.model = defaultModel,
    String? reasoningEffort,
    this.customUrl = defaultUrl,
    this.systemPrompt = defaultSystemPrompt,
    super.extraApiKeys,
  }) : reasoningEffort =
           reasoningEffort ??
           ((model.trim().isEmpty || model.trim() == defaultModel)
               ? defaultReasoningEffort
               : '');

  String get resolvedUrl {
    final trimmed = customUrl.trim();
    return trimmed.isEmpty ? defaultUrl : trimmed;
  }

  String get resolvedModel {
    final trimmed = model.trim();
    return trimmed.isEmpty ? defaultModel : trimmed;
  }

  String get resolvedReasoningEffort => reasoningEffort.trim();

  String get resolvedSystemPrompt {
    final trimmed = systemPrompt.trim();
    return trimmed.isEmpty ? defaultSystemPrompt : trimmed;
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'grok',
    'id': id,
    'apiKey': apiKey,
    'model': model.trim(),
    'reasoningEffort': reasoningEffort.trim(),
    'customUrl': customUrl.trim(),
    'systemPrompt': systemPrompt,
    if (extraApiKeys.isNotEmpty) 'apiKeys': extraApiKeys,
  };

  factory GrokOptions.fromJson(Map<String, dynamic> json) => GrokOptions(
    id: json['id'],
    apiKey: json['apiKey'] ?? '',
    model: json['model'] ?? defaultModel,
    reasoningEffort: json['reasoningEffort'],
    customUrl: json['customUrl'] ?? defaultUrl,
    systemPrompt: json['systemPrompt'] ?? defaultSystemPrompt,
    extraApiKeys: SearchServiceOptions.parseExtraApiKeys(json),
  );
}

class QueritOptions extends SearchServiceOptions {
  final String apiKey;
  final String sitesInclude;
  final String sitesExclude;
  final String timeRange;
  final String countries;
  final String languages;

  QueritOptions({
    required super.id,
    required this.apiKey,
    this.sitesInclude = '',
    this.sitesExclude = '',
    this.timeRange = '',
    this.countries = '',
    this.languages = '',
    super.extraApiKeys,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'querit',
    'id': id,
    'apiKey': apiKey,
    'sitesInclude': sitesInclude.trim(),
    'sitesExclude': sitesExclude.trim(),
    'timeRange': timeRange.trim(),
    'countries': countries.trim(),
    'languages': languages.trim(),
    if (extraApiKeys.isNotEmpty) 'apiKeys': extraApiKeys,
  };

  factory QueritOptions.fromJson(Map<String, dynamic> json) => QueritOptions(
    id: json['id'],
    apiKey: json['apiKey'] ?? '',
    sitesInclude: json['sitesInclude'] ?? '',
    sitesExclude: json['sitesExclude'] ?? '',
    timeRange: json['timeRange'] ?? '',
    countries: json['countries'] ?? '',
    languages: json['languages'] ?? '',
    extraApiKeys: SearchServiceOptions.parseExtraApiKeys(json),
  );
}

class StepFunOptions extends SearchServiceOptions {
  static const String defaultUrl = 'https://api.stepfun.com/v1/search';

  final String apiKey;
  final String url;
  final String category;

  StepFunOptions({
    required super.id,
    required this.apiKey,
    this.url = '',
    this.category = '',
    super.extraApiKeys,
  });

  String get resolvedUrl {
    final trimmed = url.trim();
    return trimmed.isEmpty ? defaultUrl : trimmed;
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'stepfun',
    'id': id,
    'apiKey': apiKey,
    'url': url.trim(),
    'category': category.trim(),
    if (extraApiKeys.isNotEmpty) 'apiKeys': extraApiKeys,
  };

  factory StepFunOptions.fromJson(Map<String, dynamic> json) => StepFunOptions(
    id: json['id'],
    apiKey: json['apiKey'] ?? '',
    url: json['url'] ?? '',
    category: json['category'] ?? '',
    extraApiKeys: SearchServiceOptions.parseExtraApiKeys(json),
  );
}

class FirecrawlOptions extends SearchServiceOptions {
  static const String defaultUrl = 'https://api.firecrawl.dev/v2/search';

  final String apiKey;
  final String url;
  final List<String> sources;
  final List<String> categories;
  final String country;
  final String location;

  FirecrawlOptions({
    required super.id,
    required this.apiKey,
    this.url = '',
    this.sources = const <String>['web'],
    this.categories = const <String>[],
    this.country = '',
    this.location = '',
    super.extraApiKeys,
  });

  String get resolvedUrl {
    final trimmed = url.trim();
    return trimmed.isEmpty ? defaultUrl : trimmed;
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'firecrawl',
    'id': id,
    'apiKey': apiKey,
    'url': url.trim(),
    'sources': sources,
    'categories': categories,
    'country': country.trim(),
    'location': location.trim(),
    if (extraApiKeys.isNotEmpty) 'apiKeys': extraApiKeys,
  };

  factory FirecrawlOptions.fromJson(Map<String, dynamic> json) =>
      FirecrawlOptions(
        id: json['id'],
        apiKey: json['apiKey'] ?? '',
        url: json['url'] ?? '',
        sources:
            (json['sources'] as List?)
                ?.map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const <String>['web'],
        categories:
            (json['categories'] as List?)
                ?.map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const <String>[],
        country: json['country'] ?? '',
        location: json['location'] ?? '',
        extraApiKeys: SearchServiceOptions.parseExtraApiKeys(json),
      );
}

class TinyFishOptions extends SearchServiceOptions {
  static const String defaultUrl = 'https://api.search.tinyfish.ai';

  final String apiKey;
  final String url;
  final String location;
  final String language;
  final String includeDomains;
  final String excludeDomains;

  TinyFishOptions({
    required super.id,
    required this.apiKey,
    this.url = '',
    this.location = '',
    this.language = '',
    this.includeDomains = '',
    this.excludeDomains = '',
    super.extraApiKeys,
  });

  String get resolvedUrl {
    final trimmed = url.trim();
    return trimmed.isEmpty ? defaultUrl : trimmed;
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'tinyfish',
    'id': id,
    'apiKey': apiKey,
    'url': url.trim(),
    'location': location.trim(),
    'language': language.trim(),
    'includeDomains': includeDomains.trim(),
    'excludeDomains': excludeDomains.trim(),
    if (extraApiKeys.isNotEmpty) 'apiKeys': extraApiKeys,
  };

  factory TinyFishOptions.fromJson(Map<String, dynamic> json) =>
      TinyFishOptions(
        id: json['id'],
        apiKey: json['apiKey'] ?? '',
        url: json['url'] ?? '',
        location: json['location'] ?? '',
        language: json['language'] ?? '',
        includeDomains: json['includeDomains'] ?? '',
        excludeDomains: json['excludeDomains'] ?? '',
        extraApiKeys: SearchServiceOptions.parseExtraApiKeys(json),
      );
}

class AnySearchOptions extends SearchServiceOptions {
  static const String defaultUrl = 'https://api.anysearch.com/v1/search';

  final String apiKey;
  final String url;

  AnySearchOptions({
    required super.id,
    required this.apiKey,
    this.url = '',
    super.extraApiKeys,
  });

  String get resolvedUrl {
    final trimmed = url.trim();
    return trimmed.isEmpty ? defaultUrl : trimmed;
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'anysearch',
    'id': id,
    'apiKey': apiKey,
    'url': url.trim(),
    if (extraApiKeys.isNotEmpty) 'apiKeys': extraApiKeys,
  };

  factory AnySearchOptions.fromJson(Map<String, dynamic> json) =>
      AnySearchOptions(
        id: json['id'],
        apiKey: json['apiKey'] ?? '',
        url: json['url'] ?? '',
        extraApiKeys: SearchServiceOptions.parseExtraApiKeys(json),
      );
}

class DoubaoOptions extends SearchServiceOptions {
  final String apiKey;

  DoubaoOptions({required super.id, required this.apiKey, super.extraApiKeys});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'doubao',
    'id': id,
    'apiKey': apiKey,
    if (extraApiKeys.isNotEmpty) 'apiKeys': extraApiKeys,
  };

  factory DoubaoOptions.fromJson(Map<String, dynamic> json) => DoubaoOptions(
    id: json['id'],
    apiKey: json['apiKey'] ?? '',
    extraApiKeys: SearchServiceOptions.parseExtraApiKeys(json),
  );
}

class KelivoOptions extends SearchServiceOptions {
  static const String builtInId = 'kelivo';

  KelivoOptions({required super.id});

  @override
  Map<String, dynamic> toJson() => {'type': 'kelivo', 'id': id};

  factory KelivoOptions.fromJson(Map<String, dynamic> json) =>
      KelivoOptions(id: json['id']);
}
