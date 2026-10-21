import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/app_scope.dart';
import '../data/hub_api.dart';
import '../widgets/common.dart';

/// Sign in by pasting a Hugging Face access token.
class TokenScreen extends StatefulWidget {
  const TokenScreen({super.key});

  @override
  State<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends State<TokenScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = _controller.text.trim();
    if (!token.startsWith('hf_')) {
      setState(() => _error = 'Hugging Face tokens start with "hf_".');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.auth.signInWithToken(token);
      if (!mounted) return;
      _controller.clear();
      showMessage(context, 'Signed in as ${context.auth.user?.name}.');
      context.go('/profile');
    } on HubException catch (e) {
      setState(
        () => _error = e.isUnauthorized
            ? 'That token isn\'t valid. Check it and try again.'
            : e.message,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const BackOrHomeButton(),
      title: const Text('Access token'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Paste a Hugging Face access token. A fine-grained, read-only token is enough for browsing and private repos.',
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: HugoColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                openInApp(context, 'https://huggingface.co/settings/tokens'),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Create a token on huggingface.co'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          obscureText: _obscure,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          style: kMono.copyWith(fontSize: 15),
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Access token',
            hintText: 'hf_…',
            errorText: _error,
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Show token' : 'Hide token',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: HugoColors.onAmber,
                  ),
                )
              : const Text('Sign in'),
        ),
        const SizedBox(height: 20),
        const HugoCard(
          child: Text(
            'To like repos you need a token with write access. To use Chat, enable "Make calls to Inference Providers". The token is kept in secure storage on this device and is only sent to huggingface.co.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: HugoColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}
