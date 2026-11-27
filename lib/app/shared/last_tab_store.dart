import 'package:shared_preferences/shared_preferences.dart';

/// Persists the most recently opened tab index so a game can reopen on the
/// same table after the app is closed, restarted, or reset.
class LastTabStore {
  LastTabStore({this.preferences});

  static const _key = 'last_open_tab';

  /// Injectable backing store; defaults to `SharedPreferencesAsync`.
  final SharedPreferencesAsync? preferences;

  bool _platformUnavailable = false;

  SharedPreferencesAsync get _instance =>
      preferences ?? SharedPreferencesAsync();

  /// Reads the saved tab index, or `null` when nothing valid is stored.
  Future<int?> read() async {
    if (_platformUnavailable) {
      return null;
    }
    try {
      final index = await _instance.getInt(_key);
      return index == null || index < 0 ? null : index;
    } on StateError {
      // No shared-preferences platform is configured (e.g. widget tests).
      _platformUnavailable = true;
      return null;
    }
  }

  /// Replaces the saved tab index.
  Future<void> write(int index) async {
    if (index < 0 || _platformUnavailable) {
      return;
    }
    try {
      await _instance.setInt(_key, index);
    } on StateError {
      // Persistence is unavailable; the tab switch itself still succeeds.
      _platformUnavailable = true;
    }
  }
}
