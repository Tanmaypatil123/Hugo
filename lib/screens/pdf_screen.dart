import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/hub_api.dart';
import '../widgets/common.dart';

/// Reads a PDF (e.g. an arXiv paper) inside Hugo with native rendering.
class PdfScreen extends StatefulWidget {
  const PdfScreen({super.key, required this.url, this.title});
  final String url;
  final String? title;

  @override
  State<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends State<PdfScreen> {
  final _controller = PdfViewerController();
  int? _page;
  int? _pages;
  int _attempt = 0;

  Future<void> _jumpToPage() async {
    final total = _pages;
    if (total == null) return;
    final input = TextEditingController(text: '${_page ?? 1}');
    final page = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to page'),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(helperText: '1 – $total'),
          onSubmitted: (v) => Navigator.pop(context, int.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, int.tryParse(input.text)),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    input.dispose();
    if (page != null) {
      await _controller.goToPage(pageNumber: page.clamp(1, total));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      titleSpacing: 0,
      title: Text(
        widget.title ?? 'Paper',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      actions: [
        if (_pages != null)
          TextButton(
            onPressed: _jumpToPage,
            child: Text(
              '${_page ?? 1} / $_pages',
              style: kMono.copyWith(color: HugoColors.textSecondary),
            ),
          ),
        IconButton(
          tooltip: 'Share',
          onPressed: () => shareUrl(widget.url),
          icon: const Icon(Icons.ios_share_rounded),
        ),
      ],
    ),
    body: PdfViewer.uri(
      Uri.parse(widget.url),
      key: ValueKey(_attempt),
      controller: _controller,
      timeout: const Duration(seconds: 60),
      params: PdfViewerParams(
        backgroundColor: HugoColors.background,
        margin: 8,
        pageDropShadow: null,
        onViewerReady: (doc, controller) {
          if (mounted) setState(() => _pages = doc.pages.length);
        },
        onPageChanged: (n) {
          if (mounted && n != null) setState(() => _page = n);
        },
        loadingBannerBuilder: (context, downloaded, total) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                value: total != null && total > 0 ? downloaded / total : null,
              ),
              const SizedBox(height: 12),
              Text(
                total != null && total > 0
                    ? 'Downloading ${fileSize(downloaded)} of ${fileSize(total)}'
                    : 'Downloading ${fileSize(downloaded)}',
                style: const TextStyle(color: HugoColors.textMuted),
              ),
            ],
          ),
        ),
        errorBannerBuilder: (context, error, stack, ref) => ErrorState(
          error: HubException(
            0,
            'The PDF couldn\'t be opened. Check your connection.',
          ),
          onRetry: () => setState(() => _attempt++),
        ),
      ),
    ),
  );
}
