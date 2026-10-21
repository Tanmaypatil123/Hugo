import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/config.dart';
import 'hub_api.dart';
import 'models.dart';

/// Holds the signed-in user's token and profile.
///
/// The token lives only in the platform's secure storage (Keychain on iOS,
/// Keystore-backed storage on Android) and is only ever sent to huggingface.co.
class AuthController extends ChangeNotifier {
  AuthController({FlutterSecureStorage? storage, FlutterAppAuth? appAuth})
    : _storage = storage ?? const FlutterSecureStorage(),
      _appAuth = appAuth ?? const FlutterAppAuth();

  final FlutterSecureStorage _storage;
  final FlutterAppAuth _appAuth;
  late HubApi _api;

  static const _kToken = 'hf_token';
  static const _kRefresh = 'hf_refresh_token';
  static const _kExpiry = 'hf_token_expiry';

  static const _oauthConfig = AuthorizationServiceConfiguration(
    authorizationEndpoint: 'https://huggingface.co/oauth/authorize',
    tokenEndpoint: 'https://huggingface.co/oauth/token',
  );

  String? _token;
  String? _refreshToken;
  DateTime? _expiry;
  WhoAmI? _user;
  Set<String> _likedKeys = {};
  bool _ready = false;
  Object? _profileError;

  String? get token => _token;
  WhoAmI? get user => _user;

  /// Why the signed-in user's profile couldn't be loaded, if it failed.
  Object? get profileError => _profileError;
  bool get isSignedIn => _token != null;
  bool get isReady => _ready;
  bool get oauthAvailable => HugoConfig.oauthClientId.isNotEmpty;

  void attach(HubApi api) => _api = api;

  static String likeKey(RepoType type, String id) => '${type.name}:$id';
  bool isLiked(RepoType type, String id) =>
      _likedKeys.contains(likeKey(type, id));

  Future<void> load() async {
    try {
      _token = await _storage.read(key: _kToken);
      _refreshToken = await _storage.read(key: _kRefresh);
      final exp = await _storage.read(key: _kExpiry);
      _expiry = exp == null ? null : DateTime.tryParse(exp);
    } catch (_) {
      _token = null;
    }
    _ready = true;
    notifyListeners();
    if (_token != null) await refreshProfile();
  }

  /// Validates [token] with /api/whoami-v2, then stores it.
  Future<void> signInWithToken(String token) async {
    final trimmed = token.trim();
    final me = await _api.whoami(token: trimmed);
    await _save(trimmed, null, null);
    _user = me;
    notifyListeners();
    await _loadLikes();
  }

  Future<void> signInWithOAuth() async {
    if (!oauthAvailable) {
      throw HubException(
        0,
        'Sign in with Hugging Face is not set up in this build.',
      );
    }
    final AuthorizationTokenResponse res;
    try {
      res = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          HugoConfig.oauthClientId,
          HugoConfig.oauthRedirect,
          serviceConfiguration: _oauthConfig,
          scopes: HugoConfig.oauthScopes,
        ),
      );
    } on FlutterAppAuthUserCancelledException {
      return;
    }
    final access = res.accessToken;
    if (access == null) {
      throw HubException(0, 'Sign-in did not return a token.');
    }
    await _save(access, res.refreshToken, res.accessTokenExpirationDateTime);
    await refreshProfile();
  }

  /// Refreshes an expired OAuth token. Returns false when the user must sign in again.
  Future<bool> refreshIfNeeded() async {
    if (_refreshToken == null || _expiry == null) return true;
    if (DateTime.now().isBefore(
      _expiry!.subtract(const Duration(minutes: 2)),
    )) {
      return true;
    }
    try {
      final res = await _appAuth.token(
        TokenRequest(
          HugoConfig.oauthClientId,
          HugoConfig.oauthRedirect,
          refreshToken: _refreshToken,
          serviceConfiguration: _oauthConfig,
        ),
      );
      if (res.accessToken == null) return false;
      await _save(
        res.accessToken!,
        res.refreshToken ?? _refreshToken,
        res.accessTokenExpirationDateTime,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> refreshProfile() async {
    if (_token == null) return;
    if (!await refreshIfNeeded()) {
      await signOut();
      return;
    }
    _profileError = null;
    notifyListeners();
    try {
      _user = await _api.whoami();
      notifyListeners();
      await _loadLikes();
    } on HubException catch (e) {
      if (e.isUnauthorized) {
        await signOut();
        return;
      }
      debugPrint('whoami failed: ${e.statusCode} ${e.serverDetail ?? e}');
      _profileError = e;
      notifyListeners();
    } catch (e) {
      debugPrint('whoami failed: $e');
      _profileError = e;
      notifyListeners();
    }
  }

  Future<void> _loadLikes() async {
    final me = _user;
    if (me == null) return;
    try {
      final liked = await _api.likes(me.name);
      _likedKeys = {for (final r in liked) likeKey(r.type, r.id)};
      notifyListeners();
    } on HubException {
      // Likes are a nice-to-have; ignore failures.
    }
  }

  Future<void> setLiked(RepoType type, String id, bool liked) async {
    await _api.setLiked(type, id, liked);
    final key = likeKey(type, id);
    liked ? _likedKeys.add(key) : _likedKeys.remove(key);
    notifyListeners();
  }

  Future<void> _save(String token, String? refresh, DateTime? expiry) async {
    _token = token;
    _refreshToken = refresh;
    _expiry = expiry;
    await _storage.write(key: _kToken, value: token);
    if (refresh != null) {
      await _storage.write(key: _kRefresh, value: refresh);
    } else {
      await _storage.delete(key: _kRefresh);
    }
    if (expiry != null) {
      await _storage.write(key: _kExpiry, value: expiry.toIso8601String());
    } else {
      await _storage.delete(key: _kExpiry);
    }
    notifyListeners();
  }

  /// Signs out and deletes every stored credential from the device.
  Future<void> signOut() async {
    _token = null;
    _refreshToken = null;
    _expiry = null;
    _user = null;
    _profileError = null;
    _likedKeys = {};
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kExpiry);
    notifyListeners();
  }
}
