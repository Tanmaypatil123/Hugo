import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_scope.dart';
import '../data/hub_api.dart';
import '../data/models.dart';
import 'common.dart';

/// Heart button that likes/unlikes a repo on the Hub.
class LikeButton extends StatefulWidget {
  const LikeButton({super.key, required this.type, required this.id});
  final RepoType type;
  final String id;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool _busy = false;

  Future<void> _toggle() async {
    final auth = context.auth;
    if (!auth.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sign in to like repos.'),
          action: SnackBarAction(
            label: 'Sign in',
            onPressed: () => context.go('/profile'),
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await auth.setLiked(
        widget.type,
        widget.id,
        !auth.isLiked(widget.type, widget.id),
      );
    } on HubException catch (e) {
      if (!mounted) return;
      if (e.isForbidden || e.isUnauthorized) {
        // The Hub rejects likes made with access tokens ("Invalid username or
        // password"), so fall back to the website, where the user is signed in.
        showMessage(
          context,
          'Liking works on huggingface.co. Opening the page…',
        );
        await openInApp(context, widget.type.webUrl(widget.id));
      } else {
        showMessage(context, e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: context.auth,
    builder: (context, _) {
      final liked = context.auth.isLiked(widget.type, widget.id);
      return IconButton(
        tooltip: liked ? 'Unlike' : 'Like',
        onPressed: _busy ? null : _toggle,
        icon: Icon(
          liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: liked ? HugoColors.amber : null,
        ),
      );
    },
  );
}

class ShareButton extends StatelessWidget {
  const ShareButton({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Share',
    onPressed: () => shareUrl(url),
    icon: const Icon(Icons.ios_share_rounded),
  );
}

/// Renders a repo's README.md as native Markdown.
class RepoCard extends StatefulWidget {
  const RepoCard({super.key, required this.type, required this.id});
  final RepoType type;
  final String id;

  @override
  State<RepoCard> createState() => _RepoCardState();
}

class _RepoCardState extends State<RepoCard> {
  Future<String?>? _readme;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _readme ??= context.api.rawFile(widget.type, widget.id, 'README.md');
  }

  @override
  Widget build(BuildContext context) => AsyncView<String?>(
    future: _readme,
    onRetry: () => setState(() {
      _readme = context.api.rawFile(widget.type, widget.id, 'README.md');
    }),
    builder: (context, text) {
      final body = text == null ? '' : cleanMarkdown(text);
      if (body.trim().isEmpty) {
        return const EmptyState(
          'This repo has no card yet.',
          icon: Icons.description_outlined,
        );
      }
      return HubMarkdown(
        data: body,
        baseUrl: '${widget.type.webUrl(widget.id)}/resolve/main/',
      );
    },
  );
}

/// Removes YAML front matter, HTML comments and tags that Markdown can't render.
String cleanMarkdown(String text) {
  var t = text.replaceAll('\r\n', '\n');
  if (t.startsWith('---\n')) {
    final end = t.indexOf('\n---', 4);
    if (end != -1) t = t.substring(t.indexOf('\n', end + 1) + 1);
  }
  t = t.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  t = t.replaceAllMapped(
    RegExp(r'<img[^>]*src="([^"]+)"[^>]*>', caseSensitive: false),
    (m) => '![](${m[1]})',
  );
  t = t.replaceAllMapped(
    RegExp(r'<a[^>]*href="([^"]+)"[^>]*>([\s\S]*?)</a>', caseSensitive: false),
    (m) {
      final label = m[2]!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      return label.isEmpty ? '' : '[$label](${m[1]})';
    },
  );
  t = t.replaceAll(
    RegExp(
      r'</?(div|p|span|br|hr|center|b|i|strong|em|sup|sub|picture|source|details|summary)[^>]*>',
      caseSensitive: false,
    ),
    '',
  );
  return t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

class HubMarkdown extends StatelessWidget {
  const HubMarkdown({super.key, required this.data, required this.baseUrl});
  final String data;
  final String baseUrl;

  String _resolve(String href) {
    if (href.startsWith('http')) return href;
    if (href.startsWith('/')) return 'https://huggingface.co$href';
    return '$baseUrl$href';
  }

  @override
  Widget build(BuildContext context) {
    final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
    return MarkdownBody(
      data: data,
      styleSheet: base.copyWith(
        p: const TextStyle(
          fontSize: 14,
          height: 1.55,
          color: HugoColors.textSecondary,
        ),
        listBullet: const TextStyle(
          fontSize: 14,
          color: HugoColors.textSecondary,
        ),
        h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        h2: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        a: const TextStyle(color: HugoColors.blue),
        code: kMono.copyWith(
          fontSize: 12.5,
          color: HugoColors.text,
          backgroundColor: HugoColors.surfaceHigh,
        ),
        codeblockDecoration: BoxDecoration(
          color: HugoColors.bar,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HugoColors.divider),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquoteDecoration: BoxDecoration(
          color: HugoColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        tableBorder: TableBorder.all(color: HugoColors.divider),
        tableHead: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        tableBody: const TextStyle(
          fontSize: 13,
          color: HugoColors.textSecondary,
        ),
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(top: BorderSide(color: HugoColors.divider)),
        ),
      ),
      onTapLink: (text, href, title) {
        if (href != null) openInApp(context, _resolve(href));
      },
      imageBuilder: (uri, title, alt) {
        final url = _resolve(uri.toString());
        if (url.toLowerCase().contains('.svg') || url.contains('shields.io')) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

/// Folder listing for a repo, used inline and as a full screen.
class FilesList extends StatefulWidget {
  const FilesList({
    super.key,
    required this.type,
    required this.id,
    this.path = '',
    this.shrinkWrap = true,
  });
  final RepoType type;
  final String id;
  final String path;
  final bool shrinkWrap;

  @override
  State<FilesList> createState() => _FilesListState();
}

class _FilesListState extends State<FilesList> {
  Future<List<TreeEntry>>? _entries;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _entries ??= context.api.tree(widget.type, widget.id, widget.path);
  }

  static const _textExt = {
    'md',
    'txt',
    'json',
    'jsonl',
    'yaml',
    'yml',
    'py',
    'toml',
    'cfg',
    'ini',
    'csv',
    'tsv',
    'js',
    'ts',
    'sh',
    'gitattributes',
    'gitignore',
    'jinja',
    'html',
    'css',
    'xml',
    'license',
  };

  bool _isText(TreeEntry e) {
    final name = e.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : name;
    return !e.isLfs &&
        e.size < 1000000 &&
        (_textExt.contains(ext) || !name.contains('.'));
  }

  void _open(TreeEntry e) {
    if (e.isDirectory) {
      context.push(
        '/files/${widget.type.name}/${widget.id}?path=${Uri.encodeQueryComponent(e.path)}',
      );
    } else if (_isText(e)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              FileViewer(type: widget.type, id: widget.id, path: e.path),
        ),
      );
    } else {
      openInApp(
        context,
        '${widget.type.webUrl(widget.id)}/blob/main/${e.path}',
      );
    }
  }

  @override
  Widget build(BuildContext context) => AsyncView<List<TreeEntry>>(
    future: _entries,
    onRetry: () => setState(() {
      _entries = context.api.tree(widget.type, widget.id, widget.path);
    }),
    builder: (context, entries) {
      if (entries.isEmpty) {
        return const EmptyState(
          'This folder is empty.',
          icon: Icons.folder_open_rounded,
        );
      }
      final tiles = [
        for (final e in entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => _open(e),
            leading: Icon(
              e.isDirectory
                  ? Icons.folder_rounded
                  : Icons.insert_drive_file_outlined,
              color: e.isDirectory
                  ? HugoColors.amber
                  : (e.isLfs ? HugoColors.blueText : HugoColors.textMuted),
            ),
            title: Text(
              e.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kMono.copyWith(fontSize: 14),
            ),
            trailing: Text(
              e.isDirectory
                  ? ''
                  : '${fileSize(e.size)}${e.isLfs ? ' · LFS' : ''}',
              style: const TextStyle(fontSize: 12, color: HugoColors.textMuted),
            ),
          ),
      ];
      if (widget.shrinkWrap) return Column(children: tiles);
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: tiles,
      );
    },
  );
}

class FileViewer extends StatefulWidget {
  const FileViewer({
    super.key,
    required this.type,
    required this.id,
    required this.path,
  });
  final RepoType type;
  final String id;
  final String path;

  @override
  State<FileViewer> createState() => _FileViewerState();
}

class _FileViewerState extends State<FileViewer> {
  Future<String?>? _text;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _text ??= context.api.rawFile(widget.type, widget.id, widget.path);
  }

  @override
  Widget build(BuildContext context) {
    final isMarkdown = widget.path.toLowerCase().endsWith('.md');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.path.split('/').last,
          style: kMono.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          ShareButton(
            url: '${widget.type.webUrl(widget.id)}/blob/main/${widget.path}',
          ),
        ],
      ),
      body: AsyncView<String?>(
        future: _text,
        onRetry: () => setState(() {
          _text = context.api.rawFile(widget.type, widget.id, widget.path);
        }),
        builder: (context, text) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: isMarkdown
              ? HubMarkdown(
                  data: cleanMarkdown(text ?? ''),
                  baseUrl: '${widget.type.webUrl(widget.id)}/resolve/main/',
                )
              : SelectableText(
                  text ?? '',
                  style: kMono.copyWith(
                    fontSize: 12.5,
                    height: 1.5,
                    color: HugoColors.textSecondary,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Section switcher used on detail screens (Model card / Files / ...).
class DetailTabs extends StatelessWidget {
  const DetailTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: HugoColors.divider)),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              selected: i == index,
              button: true,
              child: InkWell(
                onTap: () => onChanged(i),
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == index
                            ? HugoColors.amber
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: i == index
                          ? HugoColors.text
                          : HugoColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Owner line that links to the user/org profile.
class OwnerLink extends StatelessWidget {
  const OwnerLink({super.key, required this.owner});
  final String owner;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.push('/$owner'),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        owner,
        style: kMono.copyWith(fontSize: 13, color: HugoColors.textMuted),
      ),
    ),
  );
}
