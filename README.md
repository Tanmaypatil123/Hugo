<p align="center">
  <img src="assets/logo/hugo_logo.svg" alt="Hugo logo" width="96" height="96">
</p>

# Hugo

An open-source mobile client for the [Hugging Face Hub](https://huggingface.co), built with Flutter for Android and iOS.

> Hugo is an **unofficial** app and is not affiliated with Hugging Face.

## Features

- **Home**: trending models, datasets and Spaces, plus today's papers
- **Search and filters**: task, library, license, language, "has an inference provider", and sort order
- **Model pages**: rendered model card, tags, stats, and a file browser with sizes
- **Dataset pages**: a row viewer (via datasets-server) that lets you tap a row to see every field
- **Spaces**: status, SDK and owner, and opening the Space in the in-app browser
- **Papers**: daily and trending papers, search, AI summaries, code links, linked models/datasets/Spaces, full text (arXiv HTML or PDF), and a saved list kept on the device
- **Profiles**: users and organizations with their repos
- **Sign-in**: "Sign in with Hugging Face" (OAuth + PKCE) or a pasted access token. Guest mode works for everything that's public.
- **Chat**: open models through Hugging Face Inference Providers, billed to the user's own account. Chat history stays on the device.
- **Safe content**: repos tagged `not-for-all-audiences`, and repos whose names suggest unfiltered models, are hidden by default
- **Hub links**: app routes mirror huggingface.co URLs, so `huggingface.co/...` links open the right screen

The app is dark mode only.

## Privacy

Hugo has **no backend and no analytics**. Requests go straight from the device to `huggingface.co`, `datasets-server.huggingface.co` and `router.huggingface.co`. Tokens are kept in the platform's secure storage (Keychain or Android Keystore) and are never sent anywhere else. Android backups are turned off so the token isn't copied off the device.

## Getting started

```bash
flutter pub get
flutter run
```

Requires Flutter 3.47 or later.

### Sign in with Hugging Face (optional)

1. Create an OAuth app at <https://huggingface.co/settings/applications/new>. Make it a public app (no client secret), set the redirect URI to `dev.hugo.hub://oauth/callback`, and request the scopes `openid profile read-repos inference-api`.
2. Build with your client ID:

```bash
flutter run --dart-define=HF_OAUTH_CLIENT_ID=your-client-id
```

Without a client ID the OAuth button explains that it's unavailable, and token sign-in still works.

Other build-time settings: `HUGO_REPO_URL` (the source-code link, also used for reporting chat replies; defaults to <https://github.com/Tanmaypatil123/Hugo>, so forks should set their own) and `HUGO_PRIVACY_URL`.

## Contributing

Issues and pull requests are welcome. Please run `flutter analyze` and `flutter test` before opening a PR.
