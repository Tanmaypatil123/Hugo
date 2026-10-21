import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_filter.dart';
import 'models.dart';

/// Local, non-secret preferences: content filters and saved papers.
class SettingsController extends ChangeNotifier {
  static const _kHideMature = 'hide_mature';
  static const _kHideUncensored = 'hide_uncensored';
  static const _kSavedPapers = 'saved_papers';

  SharedPreferences? _prefs;
  bool _hideMature = true;
  bool _hideUncensored = true;
  List<Map<String, dynamic>> _saved = [];

  bool get hideMature => _hideMature;
  bool get hideUncensored => _hideUncensored;
  List<Map<String, dynamic>> get savedPapers => List.unmodifiable(_saved);

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _hideMature = _prefs!.getBool(_kHideMature) ?? true;
      _hideUncensored = _prefs!.getBool(_kHideUncensored) ?? true;
      final raw = _prefs!.getString(_kSavedPapers);
      if (raw != null) {
        _saved = (jsonDecode(raw) as List)
            .cast<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList();
      }
    } catch (_) {
      // Fall back to safe defaults.
    }
    notifyListeners();
  }

  Future<void> setHideMature(bool v) async {
    _hideMature = v;
    notifyListeners();
    await _prefs?.setBool(_kHideMature, v);
  }

  Future<void> setHideUncensored(bool v) async {
    _hideUncensored = v;
    notifyListeners();
    await _prefs?.setBool(_kHideUncensored, v);
  }

  bool isSaved(String paperId) => _saved.any((p) => p['id'] == paperId);

  Future<void> toggleSaved(Paper paper) async {
    if (isSaved(paper.id)) {
      _saved.removeWhere((p) => p['id'] == paper.id);
    } else {
      _saved.insert(0, paper.toSavedJson());
    }
    notifyListeners();
    await _prefs?.setString(_kSavedPapers, jsonEncode(_saved));
  }

  /// Hides repos the user asked not to see.
  bool allows(RepoSummary repo) => allowedRepo(
    repo,
    hideMature: _hideMature,
    hideUncensored: _hideUncensored,
  );

  List<RepoSummary> filter(List<RepoSummary> repos) =>
      repos.where(allows).toList();
}
