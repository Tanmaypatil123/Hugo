/// App-wide constants. Values that differ per fork come from --dart-define.
abstract final class HugoConfig {
  static const hubBase = 'https://huggingface.co';
  static const datasetsServer = 'https://datasets-server.huggingface.co';
  static const inferenceRouter = 'https://router.huggingface.co/v1';

  /// Client ID of the public "Sign in with Hugging Face" OAuth app.
  /// Register one at huggingface.co/settings/applications and build with
  /// `--dart-define=HF_OAUTH_CLIENT_ID=...`. Empty disables OAuth sign-in.
  static const oauthClientId = String.fromEnvironment('HF_OAUTH_CLIENT_ID');
  static const oauthRedirect = 'dev.hugo.hub://oauth/callback';
  static const oauthScopes = [
    'openid',
    'profile',
    'read-repos',
    'inference-api',
  ];

  /// Where users can see the source and report problems.
  static const repoUrl = String.fromEnvironment(
    'HUGO_REPO_URL',
    defaultValue: 'https://github.com/',
  );
  static const privacyPolicyUrl = String.fromEnvironment(
    'HUGO_PRIVACY_URL',
    defaultValue: 'https://github.com/',
  );

  static const appVersion = '0.1.0';
}
