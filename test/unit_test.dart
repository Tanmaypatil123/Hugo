import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hugo_app/core/format.dart';
import 'package:hugo_app/data/hub_api.dart';
import 'package:hugo_app/data/models.dart';
import 'package:hugo_app/data/settings.dart';
import 'package:hugo_app/routes.dart';
import 'package:hugo_app/widgets/repo_widgets.dart';

void main() {
  group('format', () {
    test('compactNumber', () {
      expect(compactNumber(512), '512');
      expect(compactNumber(27737), '27.7k');
      expect(compactNumber(1919), '1.92k');
      expect(compactNumber(28577260), '28.6M');
      expect(compactNumber(172474), '172k');
    });

    test('fileSize and paramCount', () {
      expect(fileSize(3311), '3.31 kB');
      expect(fileSize(970533624), '971 MB');
      expect(paramCount(763205315794), '763B');
    });

    test('humanizeTag', () {
      expect(humanizeTag('image-text-to-text'), 'Image-Text-to-Text');
      expect(humanizeTag('text-generation'), 'Text-Generation');
    });
  });

  group('pathFromHubUrl', () {
    test('maps Hub URLs to app paths', () {
      expect(
        pathFromHubUrl('https://huggingface.co/deepseek-ai/DeepSeek-V3.2'),
        '/deepseek-ai/DeepSeek-V3.2',
      );
      expect(
        pathFromHubUrl(
          'https://huggingface.co/datasets/nvidia/Nemotron-Personas-Vietnam/viewer',
        ),
        '/datasets/nvidia/Nemotron-Personas-Vietnam',
      );
      expect(pathFromHubUrl('https://hf.co/spaces/a/b'), '/spaces/a/b');
      expect(
        pathFromHubUrl('https://huggingface.co/papers/2610.24087'),
        '/papers/2610.24087',
      );
      expect(pathFromHubUrl('https://huggingface.co/google'), '/google');
    });

    test('ignores other text', () {
      expect(pathFromHubUrl('qwen3'), isNull);
      expect(pathFromHubUrl('https://example.com/a/b'), isNull);
    });
  });

  test('content filter hides tagged and "uncensored" repos', () {
    final s = SettingsController();
    final ok = RepoSummary(id: 'Qwen/Qwen3-4B-GGUF', type: RepoType.model);
    final tagged = RepoSummary(
      id: 'x/y',
      type: RepoType.model,
      tags: const ['not-for-all-audiences'],
    );
    final named = RepoSummary(
      id: 'x/Qwen3.8-27B-Uncensored-GGUF',
      type: RepoType.model,
    );
    expect(s.filter([ok, tagged, named]).map((r) => r.id), [
      'Qwen/Qwen3-4B-GGUF',
    ]);
  });

  test('cleanMarkdown strips front matter and HTML', () {
    const md =
        '---\nlicense: mit\n---\n\n# Title\n<div align="center"><img src="logo.png" /></div>\n<!-- hidden -->Text';
    final out = cleanMarkdown(md);
    expect(out.contains('license: mit'), isFalse);
    expect(out.contains('<div'), isFalse);
    expect(out.contains('![](logo.png)'), isTrue);
    expect(out.contains('hidden'), isFalse);
    expect(out.contains('# Title'), isTrue);
  });

  group('HubApi', () {
    test('sends repeated filter params and parses repos', () async {
      late Uri seen;
      final api = HubApi(
        tokenProvider: () => 'hf_test',
        client: MockClient((req) async {
          seen = req.url;
          expect(req.headers['Authorization'], 'Bearer hf_test');
          return http.Response(
            jsonEncode([
              {
                'id': 'Qwen/Qwen3-8B-GGUF',
                'likes': 336,
                'downloads': 630107,
                'pipeline_tag': 'text-generation',
                'tags': ['gguf'],
              },
            ]),
            200,
          );
        }),
      );
      final repos = await api.listRepos(
        RepoType.model,
        search: 'qwen3',
        sort: SortOption.downloads,
        pipelineTag: 'text-generation',
        filters: const ['gguf', 'license:apache-2.0'],
      );
      expect(seen.path, '/api/models');
      expect(seen.queryParametersAll['filter'], ['gguf', 'license:apache-2.0']);
      expect(seen.queryParameters['sort'], 'downloads');
      expect(seen.queryParameters['pipeline_tag'], 'text-generation');
      expect(repos.single.owner, 'Qwen');
      expect(repos.single.downloads, 630107);
    });

    test('follows the Link header cursor and refuses non-Hub links', () async {
      final api = HubApi(
        tokenProvider: () => 'hf_test',
        client: MockClient((req) async {
          final second = req.url.queryParameters.containsKey('cursor');
          return http.Response(
            jsonEncode([
              {'id': second ? 'b/two' : 'a/one'},
            ]),
            200,
            headers: second
                ? {}
                : {
                    'link': '<https://huggingface.co/api/models?limit=1&cursor=abc>; rel="next"',
                  },
          );
        }),
      );
      final first = await api.listReposPage(RepoType.model, limit: 1);
      expect(first.items.single.id, 'a/one');
      expect(
        first.next,
        'https://huggingface.co/api/models?limit=1&cursor=abc',
      );
      final second = await api.listReposPage(
        RepoType.model,
        nextUrl: first.next,
      );
      expect(second.items.single.id, 'b/two');
      expect(second.next, isNull);
      expect(
        () => api.listReposPage(
          RepoType.model,
          nextUrl: 'https://evil.example/api/models',
        ),
        throwsA(isA<HubException>()),
        reason: 'the token must never be sent to another host',
      );
    });

    test('maps 429 to a rate-limit error', () async {
      final api = HubApi(
        tokenProvider: () => null,
        client: MockClient((_) async => http.Response('{}', 429)),
      );
      expect(
        () => api.listRepos(RepoType.dataset),
        throwsA(
          isA<HubException>().having(
            (e) => e.isRateLimited,
            'isRateLimited',
            true,
          ),
        ),
      );
    });

    test(
      'daily papers fall back to the latest day when the date is too new',
      () async {
        final seen = <Uri>[];
        final api = HubApi(
          tokenProvider: () => null,
          client: MockClient((req) async {
            seen.add(req.url);
            if (req.url.queryParameters.containsKey('date')) {
              return http.Response(
                '{"error":"\\"date\\" must be less than or equal to \\"2026-10-20T00:00:00.000Z\\""}',
                400,
              );
            }
            return http.Response(
              jsonEncode([
                {
                  'paper': {
                    'id': '1',
                    'title': 'Latest',
                    'upvotes': 5,
                    'submittedOnDailyAt': '2026-10-20T00:00:00.000Z',
                  },
                },
                {
                  'paper': {
                    'id': '2',
                    'title': 'Older',
                    'upvotes': 9,
                    'submittedOnDailyAt': '2026-10-19T00:00:00.000Z',
                  },
                },
              ]),
              200,
            );
          }),
        );
        final papers = await api.dailyPapers(DateTime(2026, 10, 21));
        expect(seen.length, 2);
        expect(papers.map((p) => p.title), [
          'Latest',
        ], reason: 'keeps only the latest day');
      },
    );

    test('parses a daily paper entry', () {
      final p = Paper.fromJson({
        'paper': {
          'id': '2610.24087',
          'title': 'OR-License',
          'upvotes': 124,
          'githubRepo': 'https://github.com/NineAbyss/OR-License',
          'authors': [
            {'name': 'Peisong Wang'},
            {'name': 'Feixue Liu'},
            {'name': 'Yize Meng'},
          ],
        },
        'numComments': 1,
      });
      expect(p.hasCode, isTrue);
      expect(p.authorLine, 'Peisong Wang, Feixue Liu +1');
      expect(p.numComments, 1);
    });
  });
}
