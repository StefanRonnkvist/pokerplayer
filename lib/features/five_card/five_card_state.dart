import 'dart:convert';

/// Serializable snapshot of a five-card game, including in-progress betting.
///
/// Card values are stored as indexes into the canonical 52-card deck so the
/// snapshot remains independent of the `PlayingCard` package's JSON shape.
class FiveCardState {
  const FiveCardState({
    required this.deckCardIndexes,
    required this.playerCardIndexes,
    required this.nextCardIndex,
    required this.handsRevealed,
    this.revealedPlayerNumbers = const {},
    this.playerCount,
    this.playerBalances = const {},
    this.playerWagers = const {},
    this.playerBets = const {},
    this.playerActions = const {},
    this.foldedPlayers = const {},
    this.pendingRaiseResponders = const [],
    this.pendingComputerPlayers = const [],
    this.payoutMessage,
    this.potAwarded = false,
    this.bettingRoundStarted = false,
  });

  /// Current on-disk schema version.
  static const version = 2;

  final List<int>? deckCardIndexes;
  final Map<int, List<int>> playerCardIndexes;
  final int nextCardIndex;
  final bool handsRevealed;
  final Set<int> revealedPlayerNumbers;
  final int? playerCount;
  final Map<int, int> playerBalances;
  final Map<int, int> playerWagers;
  final Map<int, int> playerBets;
  final Map<int, String> playerActions;
  final Set<int> foldedPlayers;
  final List<int> pendingRaiseResponders;
  final List<int> pendingComputerPlayers;
  final String? payoutMessage;
  final bool potAwarded;
  final bool bettingRoundStarted;

  /// Encodes this snapshot as versioned JSON for [FiveCardStateStore].
  String encode() => jsonEncode({
    'version': version,
    'deckCardIndexes': deckCardIndexes,
    'playerCardIndexes': {
      for (final entry in playerCardIndexes.entries)
        '${entry.key}': entry.value,
    },
    'nextCardIndex': nextCardIndex,
    'handsRevealed': handsRevealed,
    'revealedPlayerNumbers': revealedPlayerNumbers.toList()..sort(),
    'playerCount': playerCount,
    'playerBalances': _encodeIntMap(playerBalances),
    'playerWagers': _encodeIntMap(playerWagers),
    'playerBets': _encodeIntMap(playerBets),
    'playerActions': {
      for (final entry in playerActions.entries) '${entry.key}': entry.value,
    },
    'foldedPlayers': foldedPlayers.toList()..sort(),
    'pendingRaiseResponders': pendingRaiseResponders,
    'pendingComputerPlayers': pendingComputerPlayers,
    'payoutMessage': payoutMessage,
    'potAwarded': potAwarded,
    'bettingRoundStarted': bettingRoundStarted,
  });

  /// Decodes and validates a saved snapshot.
  ///
  /// Version 1 saves contain only dealt-card state; missing betting fields are
  /// migrated to empty defaults. Invalid deck, player, queue, or wager data
  /// throws [FormatException] rather than restoring a partially corrupt game.
  factory FiveCardState.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        (decoded['version'] != 1 && decoded['version'] != version)) {
      throw const FormatException('Unsupported Five Card state.');
    }
    final savedVersion = decoded['version'] as int;

    final deckCardIndexes = decoded['deckCardIndexes'] == null
        ? null
        : _cardIndexes(decoded['deckCardIndexes']);
    if (deckCardIndexes != null &&
        (deckCardIndexes.length != 52 ||
            deckCardIndexes.toSet().length != 52)) {
      throw const FormatException('Invalid saved deck.');
    }

    final nextCardIndex = decoded['nextCardIndex'];
    final handsRevealed = decoded['handsRevealed'];
    if (nextCardIndex is! int ||
        nextCardIndex < 0 ||
        nextCardIndex > 52 ||
        handsRevealed is! bool) {
      throw const FormatException('Invalid game progress.');
    }

    final savedRevealedPlayers = decoded['revealedPlayerNumbers'];
    final revealedPlayerNumbers = handsRevealed
        ? {1, 2, 3, 4, 5}
        : savedRevealedPlayers == null
        ? <int>{}
        : _playerNumbers(savedRevealedPlayers);

    final playerCardIndexes = _intListMap(decoded['playerCardIndexes']);
    if (playerCardIndexes.keys.any((player) => player < 1 || player > 5) ||
        playerCardIndexes.values.any((hand) => hand.length != 5) ||
        revealedPlayerNumbers.any(
          (player) => !playerCardIndexes.containsKey(player),
        ) ||
        (deckCardIndexes == null &&
            (playerCardIndexes.isNotEmpty ||
                nextCardIndex != 0 ||
                revealedPlayerNumbers.isNotEmpty))) {
      throw const FormatException('Invalid player state.');
    }

    final playerCount = savedVersion == 1 ? null : decoded['playerCount'];
    if (playerCount != null &&
        (playerCount is! int || playerCount < 2 || playerCount > 5)) {
      throw const FormatException('Invalid saved player count.');
    }
    final playerBalances = savedVersion == 1
        ? <int, int>{}
        : _nonNegativeIntMap(decoded['playerBalances'], 'player balances');
    final playerWagers = savedVersion == 1
        ? <int, int>{}
        : _nonNegativeIntMap(decoded['playerWagers'], 'player wagers');
    final playerBets = savedVersion == 1
        ? <int, int>{}
        : _nonNegativeIntMap(decoded['playerBets'], 'player bets');
    final playerActions = savedVersion == 1
        ? <int, String>{}
        : _actionMap(decoded['playerActions']);
    final foldedPlayers = savedVersion == 1
        ? <int>{}
        : _playerNumbers(decoded['foldedPlayers']);
    final pendingRaiseResponders = savedVersion == 1
        ? <int>[]
        : _playerNumberList(decoded['pendingRaiseResponders']);
    final pendingComputerPlayers = savedVersion == 1
        ? <int>[]
        : _playerNumberList(decoded['pendingComputerPlayers']);
    final payoutMessage = savedVersion == 1 ? null : decoded['payoutMessage'];
    final potAwarded = savedVersion == 1 ? false : decoded['potAwarded'];
    final bettingRoundStarted = savedVersion == 1
        ? false
        : decoded['bettingRoundStarted'];
    // Validate cross-field invariants after each individual field has the
    // expected shape and type.
    final savedPlayerNumbers = {
      ...playerBalances.keys,
      ...playerWagers.keys,
      ...playerBets.keys,
      ...playerActions.keys,
      ...foldedPlayers,
      ...pendingRaiseResponders,
      ...pendingComputerPlayers,
    };
    if (savedPlayerNumbers.any(
          (player) => playerCount != null && player > playerCount,
        ) ||
        playerBets.entries.any(
          (entry) => entry.value > (playerWagers[entry.key] ?? 0),
        ) ||
        (payoutMessage != null && payoutMessage is! String) ||
        potAwarded is! bool ||
        bettingRoundStarted is! bool) {
      throw const FormatException('Invalid saved betting state.');
    }

    return FiveCardState(
      deckCardIndexes: deckCardIndexes,
      playerCardIndexes: playerCardIndexes,
      nextCardIndex: nextCardIndex,
      handsRevealed: handsRevealed,
      revealedPlayerNumbers: revealedPlayerNumbers,
      playerCount: playerCount as int?,
      playerBalances: playerBalances,
      playerWagers: playerWagers,
      playerBets: playerBets,
      playerActions: playerActions,
      foldedPlayers: foldedPlayers,
      pendingRaiseResponders: pendingRaiseResponders,
      pendingComputerPlayers: pendingComputerPlayers,
      payoutMessage: payoutMessage as String?,
      potAwarded: potAwarded,
      bettingRoundStarted: bettingRoundStarted,
    );
  }
}

Map<String, int> _encodeIntMap(Map<int, int> values) => {
  for (final entry in values.entries) '${entry.key}': entry.value,
};

Map<int, int> _nonNegativeIntMap(Object? value, String description) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('Expected $description map.');
  }
  return value.map((key, value) {
    final player = int.tryParse(key);
    if (player == null ||
        player < 1 ||
        player > 5 ||
        value is! int ||
        value < 0) {
      throw FormatException('Invalid $description.');
    }
    return MapEntry(player, value);
  });
}

Map<int, String> _actionMap(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected player action map.');
  }
  const validActions = {'Bet', 'Raise', 'Call', 'Check', 'Fold'};
  return value.map((key, value) {
    final player = int.tryParse(key);
    if (player == null ||
        player < 1 ||
        player > 5 ||
        value is! String ||
        !validActions.contains(value)) {
      throw const FormatException('Invalid player action.');
    }
    return MapEntry(player, value);
  });
}

List<int> _playerNumberList(Object? value) {
  if (value is! List ||
      value.any((entry) => entry is! int || entry < 1 || entry > 5)) {
    throw const FormatException('Invalid player queue.');
  }
  final players = value.cast<int>();
  if (players.toSet().length != players.length) {
    throw const FormatException('Duplicate queued player.');
  }
  return players;
}

Set<int> _playerNumbers(Object? value) {
  if (value is! List ||
      value.any((entry) => entry is! int || entry < 1 || entry > 5)) {
    throw const FormatException('Invalid revealed players.');
  }
  final players = value.cast<int>().toSet();
  if (players.length != value.length) {
    throw const FormatException('Duplicate revealed player.');
  }
  return players;
}

List<int> _cardIndexes(Object? value) {
  if (value is! List ||
      value.any((entry) => entry is! int || entry < 0 || entry > 51)) {
    throw const FormatException('Invalid card indexes.');
  }
  return value.cast<int>();
}

Map<int, List<int>> _intListMap(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected player card map.');
  }
  return value.map((key, value) {
    final player = int.tryParse(key);
    if (player == null) {
      throw const FormatException('Invalid player number.');
    }
    return MapEntry(player, _cardIndexes(value));
  });
}
