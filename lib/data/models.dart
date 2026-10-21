enum RepoType {
  model('models', ''),
  dataset('datasets', 'datasets/'),
  space('spaces', 'spaces/');

  const RepoType(this.apiPath, this.urlPrefix);

  /// Segment used in API paths: /api/{apiPath}/{id}.
  final String apiPath;

  /// Prefix used in web URLs: huggingface.co/{urlPrefix}{id}.
  final String urlPrefix;

  String webUrl(String id) => 'https://huggingface.co/$urlPrefix$id';

  static RepoType fromName(String? name) => switch (name) {
    'dataset' || 'datasets' => RepoType.dataset,
    'space' || 'spaces' => RepoType.space,
    _ => RepoType.model,
  };
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
int _int(Object? v) => v is num ? v.toInt() : 0;
List<String> _strings(Object? v) =>
    v is List ? v.whereType<String>().toList() : const [];

/// A row in any list of models, datasets or Spaces.
class RepoSummary {
  RepoSummary({
    required this.id,
    required this.type,
    this.likes = 0,
    this.downloads = 0,
    this.pipelineTag,
    this.libraryName,
    this.sdk,
    this.tags = const [],
    this.lastModified,
    this.isPrivate = false,
    this.gated = false,
  });

  factory RepoSummary.fromJson(Map<String, dynamic> j, RepoType type) =>
      RepoSummary(
        id: (j['id'] ?? j['modelId'] ?? '') as String,
        type: type,
        likes: _int(j['likes']),
        downloads: _int(j['downloads']),
        pipelineTag: j['pipeline_tag'] as String?,
        libraryName: j['library_name'] as String?,
        sdk: j['sdk'] as String?,
        tags: _strings(j['tags']),
        lastModified: _date(j['lastModified']),
        isPrivate: j['private'] == true,
        gated: j['gated'] != null && j['gated'] != false,
      );

  final String id;
  final RepoType type;
  final int likes;
  final int downloads;
  final String? pipelineTag;
  final String? libraryName;
  final String? sdk;
  final List<String> tags;
  final DateTime? lastModified;
  final bool isPrivate;
  final bool gated;

  String get owner => id.contains('/') ? id.split('/').first : '';
  String get name => id.contains('/') ? id.substring(id.indexOf('/') + 1) : id;
}

/// Full details of one repo (model, dataset or Space).
class RepoDetail extends RepoSummary {
  RepoDetail({
    required super.id,
    required super.type,
    super.likes,
    super.downloads,
    super.pipelineTag,
    super.libraryName,
    super.sdk,
    super.tags,
    super.lastModified,
    super.isPrivate,
    super.gated,
    this.license,
    this.parameters,
    this.fileCount = 0,
    this.spaceStage,
    this.spaceHost,
    this.spaceTitle,
    this.spaceDescription,
  });

  factory RepoDetail.fromJson(Map<String, dynamic> j, RepoType type) {
    final card = (j['cardData'] as Map?)?.cast<String, dynamic>() ?? const {};
    final runtime = (j['runtime'] as Map?)?.cast<String, dynamic>();
    final safetensors = (j['safetensors'] as Map?)?.cast<String, dynamic>();
    final s = RepoSummary.fromJson(j, type);
    final licenseTag = s.tags
        .where((t) => t.startsWith('license:'))
        .map((t) => t.substring(8))
        .firstOrNull;
    return RepoDetail(
      id: s.id,
      type: type,
      likes: s.likes,
      downloads: s.downloads,
      pipelineTag: s.pipelineTag,
      libraryName: s.libraryName,
      sdk: s.sdk,
      tags: s.tags,
      lastModified: s.lastModified,
      isPrivate: s.isPrivate,
      gated: s.gated,
      license: card['license']?.toString() ?? licenseTag,
      parameters: safetensors == null ? null : _int(safetensors['total']),
      fileCount: (j['siblings'] as List?)?.length ?? 0,
      spaceStage: runtime?['stage'] as String?,
      spaceHost: j['host'] as String?,
      spaceTitle: card['title'] as String?,
      spaceDescription: card['short_description'] as String?,
    );
  }

  final String? license;
  final int? parameters;
  final int fileCount;
  final String? spaceStage;
  final String? spaceHost;
  final String? spaceTitle;
  final String? spaceDescription;
}

class TreeEntry {
  TreeEntry({
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.isLfs = false,
  });

  factory TreeEntry.fromJson(Map<String, dynamic> j) => TreeEntry(
    path: j['path'] as String,
    isDirectory: j['type'] == 'directory',
    size: _int((j['lfs'] as Map?)?['size'] ?? j['size']),
    isLfs: j['lfs'] != null,
  );

  final String path;
  final bool isDirectory;
  final int size;
  final bool isLfs;

  String get name => path.split('/').last;
}

class LinkedRepo {
  LinkedRepo({required this.id, required this.type, this.detail});
  final String id;
  final RepoType type;
  final String? detail;
}

class Paper {
  Paper({
    required this.id,
    required this.title,
    this.summary = '',
    this.aiSummary,
    this.aiKeywords = const [],
    this.upvotes = 0,
    this.numComments = 0,
    this.publishedAt,
    this.dailyDate,
    this.authors = const [],
    this.githubRepo,
    this.githubStars,
    this.projectPage,
    this.linked = const [],
  });

  /// Accepts a plain paper object, or a daily/search entry `{paper: {...}}`.
  factory Paper.fromJson(Map<String, dynamic> raw) {
    final j = (raw['paper'] as Map?)?.cast<String, dynamic>() ?? raw;
    final linked = <LinkedRepo>[
      for (final m in (j['linkedModels'] as List? ?? const []))
        LinkedRepo(
          id: m['id'] as String,
          type: RepoType.model,
          detail: m['pipeline_tag'] as String?,
        ),
      for (final d in (j['linkedDatasets'] as List? ?? const []))
        LinkedRepo(id: d['id'] as String, type: RepoType.dataset),
      for (final s in (j['linkedSpaces'] as List? ?? const []))
        LinkedRepo(
          id: s['id'] as String,
          type: RepoType.space,
          detail: s['shortDescription'] as String?,
        ),
    ];
    return Paper(
      id: j['id'] as String,
      title: (raw['title'] ?? j['title'] ?? '') as String,
      summary: (j['summary'] ?? '') as String,
      aiSummary: j['ai_summary'] as String?,
      aiKeywords: _strings(j['ai_keywords']),
      upvotes: _int(j['upvotes']),
      numComments: _int(raw['numComments']),
      publishedAt: _date(j['publishedAt']),
      dailyDate: _date(j['submittedOnDailyAt']),
      authors: [
        for (final a in (j['authors'] as List? ?? const []))
          if (a is Map && a['name'] is String) a['name'] as String,
      ],
      githubRepo: j['githubRepo'] as String?,
      githubStars: j['githubStars'] == null ? null : _int(j['githubStars']),
      projectPage: j['projectPage'] as String?,
      linked: linked,
    );
  }

  final String id;
  final String title;
  final String summary;
  final String? aiSummary;
  final List<String> aiKeywords;
  final int upvotes;
  final int numComments;
  final DateTime? publishedAt;

  /// The (UTC) day this paper was featured in Daily Papers.
  final DateTime? dailyDate;
  final List<String> authors;
  final String? githubRepo;
  final int? githubStars;
  final String? projectPage;
  final List<LinkedRepo> linked;

  bool get hasCode => githubRepo != null && githubRepo!.isNotEmpty;

  String get authorLine {
    if (authors.isEmpty) return '';
    if (authors.length <= 2) return authors.join(', ');
    return '${authors.take(2).join(', ')} +${authors.length - 2}';
  }

  Map<String, dynamic> toSavedJson() => {'id': id, 'title': title};
}

/// Profile of a user or an organization.
class OwnerOverview {
  OwnerOverview({
    required this.name,
    required this.isOrg,
    this.fullname,
    this.avatarUrl,
    this.isVerified = false,
    this.isPro = false,
    this.followers = 0,
    this.members = 0,
    this.models = 0,
    this.datasets = 0,
    this.spaces = 0,
    this.papers = 0,
  });

  factory OwnerOverview.fromJson(
    Map<String, dynamic> j, {
    required bool isOrg,
  }) => OwnerOverview(
    name: (j['name'] ?? j['user'] ?? '') as String,
    isOrg: isOrg,
    fullname: j['fullname'] as String?,
    avatarUrl: _avatar(j['avatarUrl'] as String?),
    isVerified: j['isVerified'] == true,
    isPro: j['isPro'] == true,
    followers: _int(j['numFollowers']),
    members: _int(j['numUsers']),
    models: _int(j['numModels']),
    datasets: _int(j['numDatasets']),
    spaces: _int(j['numSpaces']),
    papers: _int(j['numPapers']),
  );

  final String name;
  final bool isOrg;
  final String? fullname;
  final String? avatarUrl;
  final bool isVerified;
  final bool isPro;
  final int followers;
  final int members;
  final int models;
  final int datasets;
  final int spaces;
  final int papers;
}

String? _avatar(String? url) {
  if (url == null || url.isEmpty) return null;
  return url.startsWith('http') ? url : 'https://huggingface.co$url';
}

class WhoAmI {
  WhoAmI({
    required this.name,
    this.fullname,
    this.avatarUrl,
    this.orgs = const [],
  });

  factory WhoAmI.fromJson(Map<String, dynamic> j) => WhoAmI(
    name: j['name'] as String,
    fullname: j['fullname'] as String?,
    avatarUrl: _avatar(j['avatarUrl'] as String?),
    orgs: [
      for (final o in (j['orgs'] as List? ?? const []))
        if (o is Map && o['name'] is String) o['name'] as String,
    ],
  );

  final String name;
  final String? fullname;
  final String? avatarUrl;
  final List<String> orgs;
}

class DatasetSplit {
  DatasetSplit(this.config, this.split);
  final String config;
  final String split;
  String get label => config == 'default' ? split : '$config · $split';
}

class RowsPage {
  RowsPage({required this.columns, required this.rows, required this.total});
  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final int total;
}

class ChatModelInfo {
  ChatModelInfo({required this.id, this.vision = false});

  factory ChatModelInfo.fromJson(Map<String, dynamic> j) {
    final arch = (j['architecture'] as Map?)?.cast<String, dynamic>();
    final inputs = _strings(arch?['input_modalities']);
    return ChatModelInfo(
      id: j['id'] as String,
      vision: inputs.contains('image'),
    );
  }

  final String id;
  final bool vision;
  String get shortName => id.split('/').last;
}

class ChatMessage {
  ChatMessage({required this.role, required this.content});

  factory ChatMessage.fromJson(Map<String, dynamic> j) =>
      ChatMessage(role: j['role'] as String, content: j['content'] as String);

  final String role; // 'user' | 'assistant' | 'system'
  String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}
