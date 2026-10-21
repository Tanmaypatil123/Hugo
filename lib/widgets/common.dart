import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/hub_api.dart';
import '../screens/pdf_screen.dart';
import '../screens/web_screen.dart';

/// Opens a web page inside Hugo's own web view, so the user stays in the app.
///
/// PDFs open in Hugo's native PDF reader.
Future<void> openInApp(
  BuildContext context,
  String url, {
  String? title,
  String? spaceId,
}) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
    showMessage(context, 'Could not open $url');
    return;
  }
  final navigator = Navigator.of(context, rootNavigator: true);
  if (isPdfUrl(uri)) {
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => PdfScreen(url: url, title: title),
      ),
    );
    return;
  }
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => WebScreen(url: url, title: title, spaceId: spaceId),
    ),
  );
}

bool isPdfUrl(Uri uri) =>
    uri.path.toLowerCase().endsWith('.pdf') ||
    (uri.host.endsWith('arxiv.org') && uri.path.startsWith('/pdf/'));

Future<void> shareUrl(String url) =>
    SharePlus.instance.share(ShareParams(uri: Uri.parse(url)));

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// The Hugo mark: a model cube held by two arms.
///
/// Drawn on a 32×32 grid. Keep it in sync with `assets/logo/hugo_logo.svg`
/// and `tool/generate_icons.py`, which build the launcher icons.
class HugoLogo extends StatelessWidget {
  const HugoLogo({super.key, this.size = 34});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _LogoPainter()),
  );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 32;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(8 * s)),
      Paint()..color = HugoColors.amber,
    );
    Offset p(double x, double y) => Offset(x * s, y * s);
    final topFace = Path()
      ..moveTo(p(16, 8).dx, p(16, 8).dy)
      ..lineTo(p(23, 12).dx, p(23, 12).dy)
      ..lineTo(p(16, 16).dx, p(16, 16).dy)
      ..lineTo(p(9, 12).dx, p(9, 12).dy)
      ..close();
    canvas.drawPath(topFace, Paint()..color = HugoColors.onAmber);
    final stroke = Paint()
      ..color = HugoColors.onAmber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final cube = Path()
      ..moveTo(p(16, 8).dx, p(16, 8).dy)
      ..lineTo(p(23, 12).dx, p(23, 12).dy)
      ..lineTo(p(23, 20).dx, p(23, 20).dy)
      ..lineTo(p(16, 24).dx, p(16, 24).dy)
      ..lineTo(p(9, 20).dx, p(9, 20).dy)
      ..lineTo(p(9, 12).dx, p(9, 12).dy)
      ..close()
      ..moveTo(p(16, 16).dx, p(16, 16).dy)
      ..lineTo(p(16, 24).dx, p(16, 24).dy);
    canvas.drawPath(cube, stroke);
    final arms = Path()
      ..moveTo(p(5.5, 13).dx, p(5.5, 13).dy)
      ..quadraticBezierTo(
        p(4.5, 22.5).dx,
        p(4.5, 22.5).dy,
        p(12, 25.5).dx,
        p(12, 25.5).dy,
      )
      ..moveTo(p(26.5, 13).dx, p(26.5, 13).dy)
      ..quadraticBezierTo(
        p(27.5, 22.5).dx,
        p(27.5, 22.5).dy,
        p(20, 25.5).dx,
        p(20, 25.5).dy,
      );
    canvas.drawPath(arms, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const _tints = [
  Color(0xFF2B3A6B),
  Color(0xFF1E4D3A),
  Color(0xFF4A2E5C),
  Color(0xFF5C3A1E),
  Color(0xFF1E3F4D),
  Color(0xFF4D1E2E),
  Color(0xFF3D2B6B),
  Color(0xFF2F4A1A),
];

Color tintFor(String key) => _tints[key.hashCode.abs() % _tints.length];

/// Rounded square avatar: a picture when we have one, initials otherwise.
class OwnerAvatar extends StatelessWidget {
  const OwnerAvatar({super.key, required this.name, this.url, this.size = 42});
  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.26);
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tintFor(name), borderRadius: radius),
      alignment: Alignment.center,
      child: Text(
        initialsFor(name),
        style: TextStyle(fontSize: size * 0.3, fontWeight: FontWeight.w700),
      ),
    );
    if (url == null) return fallback;
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

enum PillTone { neutral, amber, blue, green }

class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.tone = PillTone.neutral,
    this.icon,
    this.mono = false,
  });
  final String label;
  final PillTone tone;
  final IconData? icon;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.neutral => (HugoColors.surfaceHigh, HugoColors.textSecondary),
      PillTone.amber => (HugoColors.amberSoft, HugoColors.amber),
      PillTone.blue => (HugoColors.blueSoft, HugoColors.blueText),
      PillTone.green => (HugoColors.greenSoft, HugoColors.green),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: (mono ? kMono : const TextStyle()).copyWith(
              fontSize: 12,
              color: fg,
              fontWeight: tone == PillTone.neutral
                  ? FontWeight.w500
                  : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

/// Bordered card used across the app.
class HugoCard extends StatelessWidget {
  const HugoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: HugoColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: HugoColors.divider),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => HugoCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: HugoColors.textMuted),
        ),
      ],
    ),
  );
}

/// Loading, error and retry states for a future.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.future,
    required this.builder,
    required this.onRetry,
    this.sliver = false,
  });

  final Future<T>? future;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onRetry;
  final bool sliver;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snap) {
      Widget wrap(Widget w) =>
          sliver ? SliverFillRemaining(hasScrollBody: false, child: w) : w;
      if (snap.connectionState != ConnectionState.done) {
        return wrap(
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
        );
      }
      if (snap.hasError) {
        return wrap(ErrorState(error: snap.error!, onRetry: onRetry));
      }
      return builder(context, snap.data as T);
    },
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is HubException
        ? error.toString()
        : 'Something went wrong.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: HugoColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: HugoColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(minimumSize: const Size(120, 44)),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.message, {
    super.key,
    this.icon = Icons.search_off_rounded,
  });
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: HugoColors.textMuted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: HugoColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

/// Segmented chips used for Models / Datasets / Spaces style switches.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final v in values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _Choice(
              label: label(v),
              selected: v == selected,
              onTap: () => onSelected(v),
            ),
          ),
      ],
    ),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? HugoColors.amber : HugoColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? HugoColors.amber : HugoColors.border,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? HugoColors.onAmber : HugoColors.textSecondary,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Back arrow, or a Home button when the screen was opened straight from a
/// huggingface.co link and there is nothing to go back to.
class BackOrHomeButton extends StatelessWidget {
  const BackOrHomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (Navigator.of(context).canPop()) return const BackButton();
    return IconButton(
      tooltip: 'Home',
      icon: const Icon(Icons.home_outlined),
      onPressed: () => GoRouter.of(context).go('/'),
    );
  }
}

/// "Sign in with Hugging Face", styled after Hugging Face's own light sign-in
/// badge so it reads as a third-party sign-in rather than a Hugo action.
class HuggingFaceSignInButton extends StatelessWidget {
  const HuggingFaceSignInButton({
    super.key,
    required this.onPressed,
    this.busy = false,
  });

  final VoidCallback? onPressed;
  final bool busy;

  static const _background = Color(0xFFFFFFFF);
  static const _foreground = Color(0xFF0B0F19);

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: _background,
      foregroundColor: _foreground,
      disabledBackgroundColor: _background.withValues(alpha: 0.85),
      disabledForegroundColor: _foreground,
    ),
    child: busy
        ? const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _foreground,
            ),
          )
        : const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Text('🤗', style: TextStyle(fontSize: 22, height: 1)),
              ),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Sign in with Hugging Face',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
  );
}
