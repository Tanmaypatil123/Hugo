import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import 'models.dart';

class HubException implements Exception {
  HubException(this.statusCode, this.message, {this.serverDetail});
  final int statusCode;
  final String message;

  /// The Hub's own error text, for debugging. Not shown to users.
  final String? serverDetail;

  bool get isRateLimited => statusCode == 429;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

class RepoPage {
  RepoPage({required this.items, this.next});
  final List<RepoSummary> items;

  /// URL of the next page, or null on the last page.
  final String? next;
}

enum SortOption {
  trending('trendingScore', 'Trending'),
  downloads('downloads', 'Most downloads'),
  likes('likes', 'Most likes'),
  updated('lastModified', 'Recently updated'),
  created('createdAt', 'Newest');

  const SortOption(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

/// Thin client for the public Hugging Face Hub REST API.
///
/// Hugo has no server: every request goes straight from the device to
/// huggingface.co (or its datasets-server / inference router subdomains).
class HubApi {
  HubApi({http.Client? client, required this.tokenProvider})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Returns the signed-in user's token, or null for guest mode.
  final String? Function() tokenProvider;

  static const _userAgent =
      'Hugo/${HugoConfig.appVersion} (open-source Hub client)';

  Map<String, String> _headers({bool json = false}) {
    final token = tokenProvider();
    return {
      'User-Agent': _userAgent,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (json) 'Content-Type': 'application/json',
    };
  }

  Uri _hub(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('${HugoConfig.hubBase}$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(
      queryParameters: {
        for (final e in query.entries)
          if (e.value != null) e.key: e.value is List ? e.value : '${e.value}',
      },
    );
  }

  Future<http.Response> _send(Future<http.Response> request) async {
    final http.Response res;
    try {
      res = await request.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw HubException(0, 'The request timed out. Check your connection.');
    } catch (_) {
      throw HubException(
        0,
        'Could not reach huggingface.co. Check your connection.',
      );
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return res;
    final body = res.body;
    throw HubException(
      res.statusCode,
      _errorMessage(res),
      serverDetail: body.length > 300 ? body.substring(0, 300) : body,
    );
  }

  String _errorMessage(http.Response res) {
    switch (res.statusCode) {
      case 401:
        return tokenProvider() == null
            ? 'Sign in to do this.'
            : 'Your token doesn\'t allow this, or it has expired. Check its permissions or sign in again.';
      case 403:
        return 'You don\'t have access to this. It may be gated or private.';
      case 404:
        return 'Not found.';
      case 429:
        return 'Too many requests. Sign in to get a higher rate limit.';
    }
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] is String) {
        return body['error'] as String;
      }
    } catch (_) {}
    return 'Something went wrong (HTTP ${res.statusCode}).';
  }

  Future<dynamic> _getJson(Uri uri) async {
    final res = await _send(_client.get(uri, headers: _headers()));
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  // ---------------------------------------------------------------- repos

  /// Lists models, datasets or Spaces.
  ///
  /// [filters] become repeated `filter=` params; the Hub ANDs them. Library,
  /// language and license all go through `filter` (`gguf`, `hi`,
  /// `license:mit`) because the `library=` and `language=` params are ignored.
  Future<List<RepoSummary>> listRepos(
    RepoType type, {
    String? search,
    SortOption sort = SortOption.trending,
    String? pipelineTag,
    List<String> filters = const [],
    String? author,
    bool withInferenceProvider = false,
    int limit = 30,
  }) async => (await listReposPage(
    type,
    search: search,
    sort: sort,
    pipelineTag: pipelineTag,
    filters: filters,
    author: author,
    withInferenceProvider: withInferenceProvider,
    limit: limit,
  )).items;

  /// One page of a repo list. Pass the previous page's [RepoPage.next] as
  /// [nextUrl] to get the following page (the Hub paginates with a cursor in
  /// the `Link` header).
  Future<RepoPage> listReposPage(
    RepoType type, {
    String? search,
    SortOption sort = SortOption.trending,
    String? pipelineTag,
    List<String> filters = const [],
    String? author,
    bool withInferenceProvider = false,
    int limit = 30,
    String? nextUrl,
  }) async {
    final Uri uri;
    if (nextUrl != null) {
      uri = Uri.parse(nextUrl);
      // The token is attached to every request, so only follow links back to the Hub.
      if (uri.scheme != 'https' || uri.host != 'huggingface.co') {
        throw HubException(0, 'Unexpected next-page link.');
      }
    } else {
      var sortValue = sort.apiValue;
      if (type == RepoType.space && sort == SortOption.downloads) {
        sortValue = SortOption.likes.apiValue;
      }
      uri = _hub('/api/${type.apiPath}', {
        if (search != null && search.isNotEmpty) 'search': search,
        'sort': sortValue,
        'limit': '$limit',
        if (pipelineTag != null && type == RepoType.model)
          'pipeline_tag': pipelineTag,
        if (filters.isNotEmpty) 'filter': filters,
        'author': ?author,
        if (withInferenceProvider && type == RepoType.model)
          'inference_provider': 'all',
      });
    }
    final res = await _send(_client.get(uri, headers: _headers()));
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return RepoPage(
      items: [
        for (final j in data) RepoSummary.fromJson((j as Map).cast(), type),
      ],
      next: _nextLink(res.headers['link']),
    );
  }

  static String? _nextLink(String? header) {
    if (header == null) return null;
    final m = RegExp(r'<([^>]+)>\s*;\s*rel="next"').firstMatch(header);
    return m?.group(1);
  }

  Future<RepoDetail> repo(RepoType type, String id) async {
    final data = await _getJson(_hub('/api/${type.apiPath}/$id'));
    return RepoDetail.fromJson((data as Map).cast(), type);
  }

  Future<List<TreeEntry>> tree(
    RepoType type,
    String id, [
    String path = '',
  ]) async {
    final suffix = path.isEmpty ? '' : '/$path';
    final data = await _getJson(
      _hub('/api/${type.apiPath}/$id/tree/main$suffix'),
    );
    final entries = [
      for (final j in data as List) TreeEntry.fromJson((j as Map).cast()),
    ];
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  /// Raw text of a file in a repo, e.g. README.md. Returns null when missing.
  Future<String?> rawFile(RepoType type, String id, String path) async {
    final uri = Uri.parse(
      '${HugoConfig.hubBase}/${type.urlPrefix}$id/raw/main/$path',
    );
    try {
      final res = await _send(_client.get(uri, headers: _headers()));
      return utf8.decode(res.bodyBytes, allowMalformed: true);
    } on HubException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  // ---------------------------------------------------------------- papers

  /// Papers featured on one day. Pass null for the latest day.
  ///
  /// Daily Papers is dated in UTC, and the Hub returns 400 for a day it
  /// hasn't published yet (e.g. "today" in India before UTC midnight), so a
  /// too-new date falls back to the latest day.
  Future<List<Paper>> dailyPapers(DateTime? date) async {
    dynamic data;
    if (date != null) {
      final y = date.year.toString().padLeft(4, '0');
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');
      try {
        data = await _getJson(
          _hub('/api/daily_papers', {'date': '$y-$m-$d', 'limit': '100'}),
        );
      } on HubException catch (e) {
        if (e.statusCode != 400) rethrow;
      }
    }
    final latest = data == null;
    data ??= await _getJson(_hub('/api/daily_papers', {'limit': '100'}));
    var papers = [
      for (final j in data as List) Paper.fromJson((j as Map).cast()),
    ];
    if (latest && papers.isNotEmpty && papers.first.dailyDate != null) {
      final day = papers.first.dailyDate!;
      papers = papers
          .where((p) => p.dailyDate == null || _sameDay(p.dailyDate!, day))
          .toList();
    }
    papers.sort((a, b) => b.upvotes.compareTo(a.upvotes));
    return papers;
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final x = a.toUtc(), y = b.toUtc();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  Future<List<Paper>> trendingPapers() async {
    final data = await _getJson(
      _hub('/api/papers', {'sort': 'trending', 'limit': '50'}),
    );
    return [for (final j in data as List) Paper.fromJson((j as Map).cast())];
  }

  Future<List<Paper>> searchPapers(String query) async {
    final data = await _getJson(
      _hub('/api/papers/search', {'q': query, 'limit': '30'}),
    );
    return [for (final j in data as List) Paper.fromJson((j as Map).cast())];
  }

  Future<Paper> paper(String id) async {
    final data = await _getJson(_hub('/api/papers/$id'));
    return Paper.fromJson((data as Map).cast());
  }

  // ---------------------------------------------------------------- people

  /// Loads a user, or an organization when no user has that name.
  Future<OwnerOverview> owner(String name) async {
    try {
      final data = await _getJson(_hub('/api/users/$name/overview'));
      return OwnerOverview.fromJson((data as Map).cast(), isOrg: false);
    } on HubException catch (e) {
      if (!e.isNotFound) rethrow;
    }
    final data = await _getJson(_hub('/api/organizations/$name/overview'));
    return OwnerOverview.fromJson((data as Map).cast(), isOrg: true);
  }

  Future<WhoAmI> whoami({String? token}) async {
    final headers = _headers();
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final res = await _send(
      _client.get(_hub('/api/whoami-v2'), headers: headers),
    );
    return WhoAmI.fromJson((jsonDecode(res.body) as Map).cast());
  }

  /// Repos a user has liked, as "type:id" keys plus the repo summaries.
  Future<List<RepoSummary>> likes(String username) async {
    final data = await _getJson(
      _hub('/api/users/$username/likes', {'limit': '200'}),
    );
    return [
      for (final j in data as List)
        if (j is Map && j['repo'] is Map)
          RepoSummary(
            id: j['repo']['name'] as String,
            type: RepoType.fromName(j['repo']['type'] as String?),
          ),
    ];
  }

  Future<void> setLiked(RepoType type, String id, bool liked) async {
    final uri = _hub('/api/${type.apiPath}/$id/like');
    await _send(
      liked
          ? _client.post(uri, headers: _headers())
          : _client.delete(uri, headers: _headers()),
    );
  }

  // ---------------------------------------------------------------- datasets viewer

  Uri _ds(String path, Map<String, String> query) =>
      Uri.parse('${HugoConfig.datasetsServer}$path')
          .replace(queryParameters: query);

  Future<List<DatasetSplit>> datasetSplits(String id) async {
    final data = await _getJson(_ds('/splits', {'dataset': id})) as Map;
    return [
      for (final s in (data['splits'] as List? ?? const []))
        DatasetSplit(s['config'] as String, s['split'] as String),
    ];
  }

  Future<RowsPage> datasetRows(
    String id,
    DatasetSplit split, {
    int offset = 0,
    int length = 50,
  }) async {
    final data = await _getJson(
      _ds('/rows', {
        'dataset': id,
        'config': split.config,
        'split': split.split,
        'offset': '$offset',
        'length': '$length',
      }),
    ) as Map;
    return RowsPage(
      columns: [
        for (final f in (data['features'] as List? ?? const []))
          f['name'] as String,
      ],
      rows: [
        for (final r in (data['rows'] as List? ?? const []))
          (r['row'] as Map).cast<String, dynamic>(),
      ],
      total: (data['num_rows_total'] as num?)?.toInt() ?? 0,
    );
  }

  Future<int?> datasetBytes(String id) async {
    try {
      final data = await _getJson(_ds('/size', {'dataset': id})) as Map;
      return (data['size']?['dataset']?['num_bytes_original_files'] as num?)
          ?.toInt();
    } on HubException {
      return null;
    }
  }

  // ---------------------------------------------------------------- chat

  Future<List<ChatModelInfo>> chatModels() async {
    final res = await _send(
      _client.get(
        Uri.parse('${HugoConfig.inferenceRouter}/models'),
        headers: _headers(),
      ),
    );
    final data =
        (jsonDecode(utf8.decode(res.bodyBytes)) as Map)['data'] as List;
    return [for (final j in data) ChatModelInfo.fromJson((j as Map).cast())];
  }

  /// Streams the assistant's reply token by token (OpenAI-compatible SSE).
  Stream<String> chatStream(String model, List<ChatMessage> messages) async* {
    final req =
        http.Request(
            'POST',
            Uri.parse('${HugoConfig.inferenceRouter}/chat/completions'),
          )
          ..headers.addAll(_headers(json: true))
          ..body = jsonEncode({
            'model': model,
            'stream': true,
            'messages': [for (final m in messages) m.toJson()],
          });
    final http.StreamedResponse res;
    try {
      res = await _client.send(req);
    } catch (_) {
      throw HubException(0, 'Could not reach the inference router.');
    }
    if (res.statusCode != 200) {
      final body = await res.stream.bytesToString();
      var message = 'The model returned an error (HTTP ${res.statusCode}).';
      if (res.statusCode == 401) message = 'Sign in to use chat.';
      if (res.statusCode == 402) {
        message = 'You\'ve used up your Inference Providers credits.';
      }
      try {
        final j = jsonDecode(body);
        final err = j is Map
            ? (j['error'] is Map ? j['error']['message'] : j['error'])
            : null;
        if (err is String && res.statusCode != 401) message = err;
      } catch (_) {}
      throw HubException(res.statusCode, message);
    }
    final lines = res.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload == '[DONE]') break;
      try {
        final j = jsonDecode(payload) as Map;
        final delta =
            (j['choices'] as List?)?.firstOrNull?['delta']?['content'];
        if (delta is String && delta.isNotEmpty) yield delta;
      } catch (_) {
        // Ignore keep-alive or malformed chunks.
      }
    }
  }
}
