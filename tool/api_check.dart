// Checks the Hub endpoints Hugo uses, signed in with your own token.
//
//   HF_TOKEN=hf_xxx dart run tool/api_check.dart        (macOS / Linux / Git Bash)
//   $env:HF_TOKEN="hf_xxx"; dart run tool/api_check.dart (PowerShell)
//
// The token is read from the environment only. Never commit it.
import 'dart:io';

import 'package:hugo_app/data/hub_api.dart';
import 'package:hugo_app/data/models.dart';
import 'package:hugo_app/data/content_filter.dart';

Future<void> main() async {
  final token = Platform.environment['HF_TOKEN'];
  if (token == null || token.isEmpty) {
    stderr.writeln(
      'Set HF_TOKEN first. See the comment at the top of this file.',
    );
    exit(64);
  }
  final api = HubApi(tokenProvider: () => token);
  var failures = 0;

  Future<void> check(String name, Future<String> Function() run) async {
    try {
      final result = await run();
      stdout.writeln('  ok   $name  $result');
    } on HubException catch (e) {
      failures++;
      stdout.writeln('  FAIL $name  HTTP ${e.statusCode}: ${e.message}');
      if (e.serverDetail != null && e.serverDetail!.isNotEmpty) {
        stdout.writeln('       Hub said: ${e.serverDetail}');
      }
    }
  }

  stdout.writeln('Hugo API check (signed in)\n');
  late WhoAmI me;
  await check('whoami-v2', () async {
    me = await api.whoami();
    return 'signed in as ${me.name}';
  });
  if (failures > 0) exit(1);

  await check('my models (incl. private)', () async {
    final r = await api.listRepos(
      RepoType.model,
      author: me.name,
      sort: SortOption.updated,
    );
    return '${r.length} models, ${r.where((m) => m.isPrivate).length} private';
  });
  await check(
    'my likes',
    () async => '${(await api.likes(me.name)).length} liked repos',
  );
  await check('search + filters', () async {
    final raw = await api.listRepos(
      RepoType.model,
      search: 'qwen3',
      pipelineTag: 'text-generation',
      filters: const ['gguf', 'license:apache-2.0'],
    );
    // Same default content filter the app applies.
    final r = raw.where(allowedRepo).toList();
    return '${raw.length} results, ${raw.length - r.length} hidden by the content filter, first shown: ${r.isEmpty ? '-' : r.first.id}';
  });
  await check(
    'chat models',
    () async => '${(await api.chatModels()).length} models',
  );
  await check('chat completion', () async {
    final reply = await api.chatStream('deepseek-ai/DeepSeek-V4.1-Flash', [
      ChatMessage(role: 'user', content: 'Reply with one word: hello'),
    ]).join();
    return '"${reply.trim()}"';
  });
  // Known: the Hub answers 401 for likes made with access tokens, even
  // write tokens. The app falls back to the website. Kept here to notice if
  // that ever changes.
  await check('like + unlike (expected to fail with tokens)', () async {
    const id = 'google/embeddinggemma-2';
    await api.setLiked(RepoType.model, id, true);
    await api.setLiked(RepoType.model, id, false);
    return 'liked and unliked $id';
  });

  stdout.writeln(
    failures == 0 ? '\nAll checks passed.' : '\n$failures check(s) failed.',
  );
  exit(failures == 0 ? 0 : 1);
}
