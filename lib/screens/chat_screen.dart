import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../data/app_scope.dart';
import '../data/hub_api.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/repo_widgets.dart';

const _kChatKey = 'chat_conversation';
const _kModelKey = 'chat_model';
const _kDefaultModel = 'deepseek-ai/DeepSeek-V4.1-Flash';

/// Chat with open models through Hugging Face Inference Providers,
/// billed to the signed-in user's own account. History stays on the device.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.initialModel, this.paperId});
  final String? initialModel;
  final String? paperId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  List<ChatModelInfo> _models = [];
  String _model = _kDefaultModel;
  Paper? _paper;
  StreamSubscription<String>? _sub;
  String? _error;
  bool _loadedOnce = false;

  bool get _streaming => _sub != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedOnce) return;
    _loadedOnce = true;
    _restore();
    _loadModels();
  }

  @override
  void didUpdateWidget(ChatScreen old) {
    super.didUpdateWidget(old);
    // Arriving from "Chat with this model" or "Ask AI" while Chat is already open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialModel != null &&
          widget.initialModel != old.initialModel) {
        _pickModel(widget.initialModel!, announce: true);
      }
      if (widget.paperId != null && widget.paperId != old.paperId) {
        _attachPaper(widget.paperId!);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kChatKey);
      final saved = prefs.getString(_kModelKey);
      if (!mounted) return;
      setState(() {
        if (raw != null) {
          _messages
            ..clear()
            ..addAll(
              (jsonDecode(raw) as List).map(
                (m) => ChatMessage.fromJson((m as Map).cast()),
              ),
            );
        }
        if (saved != null) _model = saved;
      });
    } catch (_) {}
    if (widget.initialModel != null) {
      _pickModel(widget.initialModel!, announce: false);
    }
    if (widget.paperId != null) _attachPaper(widget.paperId!);
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kChatKey,
        jsonEncode([for (final m in _messages) m.toJson()]),
      );
      await prefs.setString(_kModelKey, _model);
    } catch (_) {}
  }

  Future<void> _loadModels() async {
    try {
      final models = await context.api.chatModels();
      models.sort((a, b) => a.id.toLowerCase().compareTo(b.id.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _models = models;
        if (!models.any((m) => m.id == _model) && models.isNotEmpty) {
          _model = models.first.id;
        }
      });
    } on HubException {
      // The picker will offer a retry.
    }
  }

  void _pickModel(String id, {required bool announce}) {
    final known = _models.isEmpty || _models.any((m) => m.id == id);
    if (!known) {
      if (announce) {
        showMessage(
          context,
          '$id isn\'t available through Inference Providers.',
        );
      }
      return;
    }
    setState(() => _model = id);
    _persist();
  }

  Future<void> _attachPaper(String id) async {
    try {
      final p = await context.api.paper(id);
      if (!mounted) return;
      setState(() => _paper = p);
      if (_input.text.isEmpty) {
        _input.text = 'Explain this paper in three simple points.';
      }
    } on HubException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  List<ChatMessage> _payload() => [
    if (_paper != null)
      ChatMessage(
        role: 'system',
        content:
            'The user is asking about the paper "${_paper!.title}" (arXiv ${_paper!.id}). '
            'Abstract: ${_paper!.summary}',
      ),
    ..._messages,
  ];

  Future<void> _send([String? text]) async {
    final content = (text ?? _input.text).trim();
    if (content.isEmpty || _streaming) return;
    if (!context.auth.isSignedIn) {
      setState(
        () => _error = 'Sign in to chat. Usage is billed to your own Hugging Face account.',
      );
      return;
    }
    if (!context.settings.chatConsent) {
      final agreed = await showChatConsent(context);
      if (!agreed || !mounted) return;
    }
    _input.clear();
    setState(() {
      _error = null;
      _messages.add(ChatMessage(role: 'user', content: content));
    });
    await _stream();
  }

  Future<void> _stream() async {
    final reply = ChatMessage(role: 'assistant', content: '');
    final payload = _payload();
    setState(() => _messages.add(reply));
    _scrollToEnd();
    final stream = context.api.chatStream(_model, payload);
    _sub = stream.listen(
      (chunk) {
        setState(() => reply.content += chunk);
        _scrollToEnd();
      },
      onError: (Object e) {
        setState(() {
          _error = e is HubException
              ? e.message
              : 'The reply failed. Try again.';
          if (reply.content.isEmpty) _messages.remove(reply);
          _sub = null;
        });
      },
      onDone: () {
        setState(() => _sub = null);
        _persist();
      },
      cancelOnError: true,
    );
  }

  void _stop() {
    _sub?.cancel();
    setState(() => _sub = null);
    _persist();
  }

  void _regenerate() {
    if (_streaming || _messages.isEmpty) return;
    if (_messages.last.role == 'assistant') _messages.removeLast();
    _stream();
  }

  void _newChat() {
    _sub?.cancel();
    setState(() {
      _sub = null;
      _messages.clear();
      _paper = null;
      _error = null;
    });
    _persist();
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _report(ChatMessage m) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Report this reply'),
        children: [
          for (final r in [
            'Harmful or unsafe',
            'Sexual content',
            'Hateful or harassing',
            'Wrong or misleading',
            'Other',
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, r),
              child: Text(r),
            ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    final body = Uri.encodeQueryComponent(
      'Model: $_model\nReason: $reason\n\nReply:\n${m.content.length > 1500 ? '${m.content.substring(0, 1500)}…' : m.content}',
    );
    final title = Uri.encodeQueryComponent('Report: AI reply ($reason)');
    final repo = HugoConfig.repoUrl.endsWith('/')
        ? HugoConfig.repoUrl
        : '${HugoConfig.repoUrl}/';
    setState(() => _messages.remove(m));
    _persist();
    showMessage(context, 'Thanks. The reply was hidden.');
    if (repo != 'https://github.com/') {
      await openInApp(context, '${repo}issues/new?title=$title&body=$body');
    }
  }

  Future<void> _openPicker() async {
    if (_models.isEmpty) await _loadModels();
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ModelPicker(models: _models, selected: _model),
    );
    if (picked != null) _pickModel(picked, announce: true);
  }

  @override
  Widget build(BuildContext context) {
    final current = _models.where((m) => m.id == _model).firstOrNull;
    final shortName = _model.split('/').last;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _openPicker,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        shortName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.expand_more_rounded, size: 18),
                  ],
                ),
                Text(
                  'via Inference Providers${current?.vision == true ? ' · Vision' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: HugoColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: _newChat,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(),
          Expanded(
            child: _messages.isEmpty
                ? _EmptyChat(
                    signedIn: context.auth.isSignedIn,
                    onSuggestion: _send,
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final isLast = i == _messages.length - 1;
                      return m.role == 'user'
                          ? _UserBubble(text: m.content)
                          : _AssistantMessage(
                              model: shortName,
                              message: m,
                              streaming: isLast && _streaming,
                              onCopy: () {
                                Clipboard.setData(
                                  ClipboardData(text: m.content),
                                );
                                showMessage(context, 'Copied.');
                              },
                              onRegenerate: isLast ? _regenerate : null,
                              onReport: () => _report(m),
                            );
                    },
                  ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: HugoCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: HugoColors.danger,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: HugoColors.textSecondary,
                        ),
                      ),
                    ),
                    if (!context.auth.isSignedIn)
                      TextButton(
                        onPressed: () => context.go('/profile'),
                        child: const Text('Sign in'),
                      ),
                  ],
                ),
              ),
            ),
          _Composer(
            controller: _input,
            model: shortName,
            paper: _paper,
            streaming: _streaming,
            onSend: _send,
            onStop: _stop,
            onRemovePaper: () => setState(() => _paper = null),
          ),
        ],
      ),
    );
  }
}

/// Asks before chat sends anything to Hugging Face and the model's provider
/// (App Store guideline 5.1.2). Returns true when the user agrees; the answer
/// is saved and can be withdrawn in Settings.
Future<bool> showChatConsent(BuildContext context) async {
  final settings = context.settings;
  final agreed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ChatConsentSheet(),
  );
  if (agreed != true) return false;
  await settings.setChatConsent(true);
  return true;
}

class _ChatConsentSheet extends StatelessWidget {
  const _ChatConsentSheet();

  static const _points = [
    (
      Icons.cloud_upload_outlined,
      'Your messages, and any paper you attach, are sent to Hugging Face and to the inference provider that runs the model you pick. They process them to write the reply.',
    ),
    (
      Icons.phone_iphone_rounded,
      'Hugo has no server of its own. Your chat history stays on this device.',
    ),
    (
      Icons.receipt_long_outlined,
      'Usage is billed to your Hugging Face account.',
    ),
    (
      Icons.privacy_tip_outlined,
      'Don\'t share passwords or other sensitive personal details. Replies are generated by AI and can be wrong.',
    ),
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Before you chat',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        for (final (icon, text) in _points)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: HugoColors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: HugoColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () =>
                openInApp(context, 'https://huggingface.co/privacy'),
            child: const Text('Hugging Face privacy policy'),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Agree and continue'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Not now',
            style: TextStyle(color: HugoColors.textSecondary),
          ),
        ),
      ],
    ),
  );
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.signedIn, required this.onSuggestion});
  final bool signedIn;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 24),
      const Center(child: HugoLogo(size: 56)),
      const SizedBox(height: 16),
      const Text(
        'Chat with open models',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        signedIn ? 'Replies are generated by AI and can be wrong.' : 'Sign in to chat. Usage is billed to your own Hugging Face account.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: HugoColors.textMuted, height: 1.5),
      ),
      const SizedBox(height: 24),
      for (final s in const [
        'Which open model is best for coding on a laptop?',
        'Explain what a GGUF file is.',
        'What does "A3B" mean in a model name?',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: HugoCard(
            onTap: () => onSuggestion(s),
            child: Text(s, style: const TextStyle(fontSize: 14)),
          ),
        ),
    ],
  );
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      margin: const EdgeInsets.only(bottom: 16, left: 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: HugoColors.border,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(fontSize: 15, height: 1.45),
      ),
    ),
  );
}

class _AssistantMessage extends StatelessWidget {
  const _AssistantMessage({
    required this.model,
    required this.message,
    required this.streaming,
    required this.onCopy,
    required this.onReport,
    this.onRegenerate,
  });

  final String model;
  final ChatMessage message;
  final bool streaming;
  final VoidCallback onCopy;
  final VoidCallback onReport;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OwnerAvatar(name: model, size: 26),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                model,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Pill('AI-generated'),
          ],
        ),
        const SizedBox(height: 8),
        if (message.content.isEmpty && streaming)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          HubMarkdown(data: message.content, baseUrl: ''),
        if (!streaming)
          Row(
            children: [
              IconButton(
                tooltip: 'Copy reply',
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
              if (onRegenerate != null)
                IconButton(
                  tooltip: 'Regenerate',
                  onPressed: onRegenerate,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                ),
              IconButton(
                tooltip: 'Report this reply',
                onPressed: onReport,
                icon: const Icon(Icons.flag_outlined, size: 18),
              ),
            ],
          ),
      ],
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.model,
    required this.paper,
    required this.streaming,
    required this.onSend,
    required this.onStop,
    required this.onRemovePaper,
  });

  final TextEditingController controller;
  final String model;
  final Paper? paper;
  final bool streaming;
  final ValueChanged<String?> onSend;
  final VoidCallback onStop;
  final VoidCallback onRemovePaper;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (paper != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InputChip(
                avatar: const Icon(
                  Icons.article_outlined,
                  size: 16,
                  color: HugoColors.amber,
                ),
                label: Text(paper!.title, overflow: TextOverflow.ellipsis),
                onDeleted: onRemovePaper,
                deleteButtonTooltipMessage: 'Remove paper',
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
            decoration: BoxDecoration(
              color: HugoColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: HugoColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(null),
                    decoration: InputDecoration(
                      hintText: 'Message $model',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                IconButton.filled(
                  tooltip: streaming ? 'Stop' : 'Send',
                  onPressed: streaming ? onStop : () => onSend(null),
                  icon: Icon(
                    streaming ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Uses your Hugging Face credits · Chats are saved on this device only',
            style: TextStyle(fontSize: 11, color: HugoColors.textFaint),
          ),
        ],
      ),
    ),
  );
}

class _ModelPicker extends StatefulWidget {
  const _ModelPicker({required this.models, required this.selected});
  final List<ChatModelInfo> models;
  final String selected;

  @override
  State<_ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends State<_ModelPicker> {
  String _query = '';
  bool _visionOnly = false;

  @override
  Widget build(BuildContext context) {
    final list = widget.models
        .where(
          (m) =>
              (!_visionOnly || m.vision) &&
              m.id.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search chat models',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: HugoColors.textMuted,
                ),
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Vision models only'),
            value: _visionOnly,
            onChanged: (v) => setState(() => _visionOnly = v),
          ),
          Expanded(
            child: widget.models.isEmpty
                ? const EmptyState(
                    'Couldn\'t load models. Check your connection.',
                    icon: Icons.cloud_off_rounded,
                  )
                : ListView.builder(
                    controller: scroll,
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final m = list[i];
                      return ListTile(
                        leading: OwnerAvatar(
                          name: m.id.split('/').first,
                          size: 34,
                        ),
                        title: Text(
                          m.shortName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          m.id.split('/').first,
                          style: kMono.copyWith(
                            fontSize: 12,
                            color: HugoColors.textMuted,
                          ),
                        ),
                        trailing: m.id == widget.selected
                            ? const Icon(
                                Icons.check_rounded,
                                color: HugoColors.amber,
                              )
                            : (m.vision
                                  ? const Pill('Vision', tone: PillTone.blue)
                                  : null),
                        onTap: () => Navigator.pop(context, m.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
