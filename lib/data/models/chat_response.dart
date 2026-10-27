class SourceCitation {
  final String title;
  final String url;
  final String? domain;
  final String? publishedDate;
  final String? sourceType;

  const SourceCitation({
    required this.title,
    required this.url,
    this.domain,
    this.publishedDate,
    this.sourceType,
  });

  factory SourceCitation.fromJson(Map<String, dynamic> json) {
    final rawTitle = (json['title']?.toString() ?? '').trim();
    final rawUrl = (json['url']?.toString() ?? '').trim();
    final rawDomain = json['domain']?.toString().trim();
    final rawDate =
        (json['published_date'] ?? json['publishedDate'])?.toString().trim();
    final rawType =
        (json['source_type'] ?? json['sourceType'])?.toString().trim();

    final domain =
        (rawDomain != null && rawDomain.isNotEmpty) ? rawDomain : null;
    final publishedDate =
        (rawDate != null && rawDate.isNotEmpty) ? rawDate : null;
    final sourceType =
        (rawType != null && rawType.isNotEmpty) ? rawType : null;

    return SourceCitation(
      title: rawTitle.isNotEmpty ? rawTitle : (domain ?? rawUrl),
      url: rawUrl,
      domain: domain,
      publishedDate: publishedDate,
      sourceType: sourceType,
    );
  }

  static List<SourceCitation> listFromJson(Object? rawList) {
    if (rawList is! List || rawList.isEmpty) {
      return const [];
    }
    final parsed = <SourceCitation>[];
    for (final item in rawList) {
      if (item is Map) {
        final citation = SourceCitation.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (citation.title.isNotEmpty || citation.url.isNotEmpty) {
          parsed.add(citation);
        }
      }
    }
    return parsed;
  }

  /// Validates [rawUrl] and returns a parsed [Uri] only if it is a well-formed
  /// `https` or `http` URL with a non-empty host.
  static Uri? tryParseValidUri(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) {
      return null;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') {
      return null;
    }

    if (!uri.hasAuthority) {
      return null;
    }

    final host = uri.host.trim();
    if (host.isEmpty ||
        host.startsWith('.') ||
        host.endsWith('.') ||
        host.contains('..')) {
      return null;
    }

    return uri;
  }

  Uri? get validUri => tryParseValidUri(url);

  bool get hasValidUrl => validUri != null;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      if (domain != null) 'domain': domain,
      if (publishedDate != null) 'published_date': publishedDate,
      if (sourceType != null) 'source_type': sourceType,
    };
  }
}

class ChatResponse {
  final bool success;
  final String response;
  final String conversationId;
  final List<SourceCitation> sources;
  final List<String> searchQueries;

  const ChatResponse({
    this.success = true,
    required this.response,
    required this.conversationId,
    this.sources = const [],
    this.searchQueries = const [],
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    final rawSuccess = json['success'];
    final success = rawSuccess is bool ? rawSuccess : true;
    final responseText = (json['response'] as String?) ?? '';
    final conversationId =
        (json['conversation_id'] as String?) ??
        (json['conversationId'] as String?) ??
        '';

    final sources = SourceCitation.listFromJson(json['sources']);

    final rawQueries = json['search_queries'] ?? json['searchQueries'];
    final searchQueries = <String>[];
    if (rawQueries is List) {
      for (final q in rawQueries) {
        if (q != null) {
          final trimmed = q.toString().trim();
          if (trimmed.isNotEmpty) {
            searchQueries.add(trimmed);
          }
        }
      }
    }

    return ChatResponse(
      success: success,
      response: responseText,
      conversationId: conversationId,
      sources: sources,
      searchQueries: searchQueries,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'response': response,
      'conversation_id': conversationId,
      'sources': sources.map((s) => s.toJson()).toList(),
      'search_queries': searchQueries,
    };
  }
}
