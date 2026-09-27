import 'package:shared_preferences/shared_preferences.dart';

/// Storage boundary for the encoded five-card game snapshot.
abstract interface class FiveCardStateStore {
  /// Reads the saved snapshot, or returns `null` when no game is stored.
  Future<String?> read();

  /// Replaces the saved snapshot with [value].
  Future<void> write(String value);

  /// Deletes any saved snapshot.
  Future<void> remove();
}

/// Persists the five-card snapshot through asynchronous shared preferences.
class SharedPreferencesFiveCardStateStore implements FiveCardStateStore {
  SharedPreferencesFiveCardStateStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _stateKey = 'five_card_state_v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() => _preferences.getString(_stateKey);

  @override
  Future<void> write(String value) => _preferences.setString(_stateKey, value);

  @override
  Future<void> remove() => _preferences.remove(_stateKey);
}
