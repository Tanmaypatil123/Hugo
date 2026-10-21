import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/theme.dart';
import '../data/hub_api.dart';
import '../routes.dart';
import '../widgets/common.dart';

/// Shows a web page (a Space, an arXiv paper, a GitHub repo) inside Hugo.
///
/// No Hugging Face token is ever sent to the page: Spaces run code written by
/// their authors, so passing the user's token would hand it to them.
class WebScreen extends StatefulWidget {
  const WebScreen({super.key, required this.url, this.title, this.spaceId});
  final String url;
  final String? title;

  /// When showing a Space, its id. A sleeping Space redirects to its own
  /// huggingface.co page to wake up; that page is allowed to load here.
  final String? spaceId;

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> {
  late final WebViewController _controller;
  late final String _startHost = Uri.parse(widget.url).host;
  String? _pageTitle;
  String _currentUrl = '';
  int _progress = 0;
  String? _error;

  /// True when a Gradio Space failed to start in this WebView.
  bool _spaceBroken = false;
  bool _checkedSpace = false;

  static const _channel = MethodChannel('dev.hugo.hub/webview');

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _controller = WebViewController();
    _setUp();
  }

  Future<void> _setUp() async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setBackgroundColor(HugoColors.background);
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (p) => mounted ? setState(() => _progress = p) : null,
        onPageStarted: (_) => mounted ? setState(() => _error = null) : null,
        onPageFinished: (_) async {
          final t = await _controller.getTitle();
          if (mounted) setState(() => _pageTitle = t);
          _checkSpaceStarted();
        },
        onUrlChange: (c) => mounted && c.url != null
            ? setState(() => _currentUrl = c.url!)
            : null,
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) {
            if (mounted) {
              setState(
                () =>
                    _error = "This page couldn't load. Check your connection.",
              );
            }
          }
        },
        onNavigationRequest: _onNavigation,
      ),
    );
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      // Android's WebView ignores <input type="file"> unless the app picks the
      // file itself (iOS handles it natively). Spaces often ask for images/audio.
      await platform.setOnShowFileSelector(_pickFiles);
      // Spaces on newer Gradio only serve Brotli files; older Android
      // WebViews can't request them. The native side fetches those files
      // itself (android/.../SpaceAssetClient.kt). Must run after the
      // navigation delegate is set, and before the page loads.
      if (widget.spaceId != null) {
        try {
          await _channel.invokeMethod<bool>(
            'enableSpaceAssetFix',
            platform.webViewIdentifier,
          );
        } catch (_) {
          // Without the fix most Spaces still work; the banner covers the rest.
        }
      }
    }
    if (mounted) await _controller.loadRequest(Uri.parse(widget.url));
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    final mimeTypes = params.acceptTypes.where((t) => t.contains('/')).toList();
    final extensions = params.acceptTypes
        .where((t) => t.startsWith('.'))
        .map((t) => t.substring(1))
        .toList();
    final group = XTypeGroup(
      label: 'Files',
      mimeTypes: mimeTypes.isEmpty ? null : mimeTypes,
      extensions: extensions.isEmpty ? null : extensions,
    );
    try {
      final files = params.mode == FileSelectorMode.openMultiple
          ? await openFiles(acceptedTypeGroups: [group])
          : [
              ?await openFile(acceptedTypeGroups: [group]),
            ];
      return [for (final f in files) Uri.file(f.path).toString()];
    } catch (_) {
      return const [];
    }
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    // Keep the user in Hugo: only web pages load here. Other schemes
    // (intent:, market:, mailto:, ...) are blocked.
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return NavigationDecision.prevent;
    }
    // PDFs (e.g. "Download paper") open in the native reader.
    if (request.isMainFrame && isPdfUrl(uri)) {
      openInApp(context, request.url);
      return NavigationDecision.prevent;
    }
    // A link from a Space or paper to a model/dataset/paper on the Hub opens
    // the native screen instead of the website.
    if (request.isMainFrame &&
        _startHost != 'huggingface.co' &&
        _startHost != 'hf.co') {
      final path = pathFromHubUrl(request.url);
      final ownSpace =
          widget.spaceId != null && path == '/spaces/${widget.spaceId}';
      if (path != null && path != '/' && !ownSpace) {
        context.push(path);
        return NavigationDecision.prevent;
      }
    }
    return NavigationDecision.navigate;
  }

  /// Spaces on newer Gradio versions only serve Brotli-compressed files and
  /// answer 404 to WebViews that don't advertise Brotli (older Android System
  /// WebView builds). The page then shows only Gradio's bare footer. Detect
  /// that and offer a Chrome tab, which supports Brotli.
  Future<void> _checkSpaceStarted() async {
    if (widget.spaceId == null || _checkedSpace) return;
    _checkedSpace = true;
    await Future<void>.delayed(const Duration(seconds: 8));
    if (!mounted) return;
    try {
      final result = await _controller.runJavaScriptReturningResult(
        "(document.querySelector('.gradio-container') || !document.body.innerText.includes('Built with Gradio')) ? 'ok' : 'broken'",
      );
      if (mounted && result.toString().contains('broken')) {
        setState(() => _spaceBroken = true);
      }
    } catch (_) {
      // Not able to inspect the page; leave it as is.
    }
  }

  Future<void> _openInChromeTab() async {
    final ok = await launchUrl(
      Uri.parse(widget.url),
      mode: LaunchMode.inAppBrowserView,
    );
    if (!ok && mounted) showMessage(context, 'Could not open the Space.');
  }

  Future<void> _openExternally() async {
    final ok = await launchUrl(
      Uri.parse(_currentUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) showMessage(context, 'Could not open the browser.');
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      if (await _controller.canGoBack()) {
        await _controller.goBack();
      } else if (context.mounted) {
        Navigator.of(context).pop();
      }
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title ?? _pageTitle ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              Uri.tryParse(_currentUrl)?.host ?? '',
              style: kMono.copyWith(fontSize: 11, color: HugoColors.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) {
              if (v == 'share') shareUrl(_currentUrl);
              if (v == 'browser') _openExternally();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'share', child: Text('Share link')),
              PopupMenuItem(value: 'browser', child: Text('Open in browser')),
            ],
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                ),
              )
            : null,
      ),
      body: _error != null
          ? ErrorState(
              error: HubException(0, _error!),
              onRetry: () => _controller.reload(),
            )
          : Column(
              children: [
                if (_spaceBroken)
                  Material(
                    color: HugoColors.surface,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: HugoColors.amber,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              "This Space can't start in Hugo's built-in viewer on this phone. Updating Android System WebView in the Play Store usually fixes it.",
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: HugoColors.textSecondary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _openInChromeTab,
                            child: const Text(
                              'Open in Chrome tab',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(child: WebViewWidget(controller: _controller)),
              ],
            ),
    ),
  );
}
