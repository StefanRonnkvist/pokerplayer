import 'package:shared_preferences/shared_preferences.dart';

/// Persists the most recent virtual-chip amount a player entered in a wager
/// dialog so the next dialog can prefill it.
class LastWagerStore {
  LastWagerStore({this.preferences});

  static const _key = 'last_wager_amount';

  /// Injectable backing store; defaults to `SharedPreferencesAsync`.
  final SharedPreferencesAsync? preferences;

  bool _platformUnavailable = false;

  SharedPreferencesAsync get _instance =>
      preferences ?? SharedPreferencesAsync();

  /// Reads the last saved wager amount, or `null` when nothing is stored.
  Future<int?> read() async {
    if (_platformUnavailable) {
      return null;
    }
    try {
      final amount = await _instance.getInt(_key);
      return amount == null || amount <= 0 ? null : amount;
    } on StateError {
      // No shared-preferences platform is configured (e.g. widget tests).
      _platformUnavailable = true;
      return null;
    }
  }

  /// Replaces the saved wager amount.
  Future<void> write(int amount) async {
    if (amount <= 0 || _platformUnavailable) {
      return;
    }
    try {
      await _instance.setInt(_key, amount);
    } on StateError {
      // Persistence is unavailable; the wager itself is still committed.
      _platformUnavailable = true;
    }
  }
}
