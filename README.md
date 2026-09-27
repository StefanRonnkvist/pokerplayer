# Play Poker

Play Poker is a Flutter poker suite with five game variants, configurable virtual-chip tables, and computer-controlled opponents. Player 1 is the user in every game, and the remaining seats are automated.

## Poker Games

- **Five Card:** Deal five cards to each player, complete a betting round, reveal active hands, and compare standard poker rankings.
- **Draw:** Complete a betting round, tap up to the configured number of cards to replace or stand pat, and take the remaining hands to showdown.
- **Stud:** Five-card stud with the first and fifth cards down, cards two through four up, and betting after every card.
- **Stud7:** Seven-card stud with the first and seventh cards down, five cards up, and betting after every card. The best five-card combination wins.
- **Hold'em:** Texas Hold'em with two private hole cards, a shared flop, turn, and river, and four betting rounds. The table uses the configured ante rather than blinds, and the best five-card combination from seven available cards wins.

## Features

- Configure 2-5 players, starting bank, and ante for the poker tables.
- Set the maximum number of replacement cards for Draw.
- Bet, raise, call, check, or fold with computer opponents that consider hand strength and pot odds.
- Enable Teach Mode to see a suggested bet for Player 1 based on the current hand, opponents, pot, call cost, and available bank.
- Award the complete virtual-chip pot to the winner or split it between tied winners.
- Continue computer play automatically after Player 1 folds.
- Compare hands from High Card through Straight Flush with tie-break rules.
- Select from 10 card-back designs and retain the selection between sessions.
- Display bankrolls and table wagers as animated stacks of chip images.
- Use responsive tables and a tab bar that fills wide screens and scrolls on narrow screens.

## App Tabs

- **Card Backs:** Select the design used by face-down cards in every game.
- **Five Card, Draw, Stud, Stud7, Hold'em:** Open a poker table for that variant.
- **Information:** Contact the developer and review submitted inquiries. These features require an internet connection.
- **Help:** Read in-app rules and control guidance.

Use the Settings button in the app bar to configure players, bankrolls, antes, Draw replacements, and Teach Mode. Suggested bets are guidance rather than a guarantee of winning.

Select **Deal** to begin a hand and post the ante. Available betting actions are highlighted: **Bet** opens the wagering, **Raise** increases it, **Call** matches it, **Check** passes when no call is required, and **Fold** leaves the hand. Wagers cannot exceed the player's available virtual-chip bank.

## State Restoration

The Five Card game restores its cards, bankrolls, wagers, player actions, folds, and result when the app reopens. The selected card back is also retained. Draw, Stud, Stud7, and Hold'em currently start fresh when their page is recreated.

All banks, antes, wagers, and pots are virtual. Play Poker does not support real-money wagering or prizes.

## Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) with Dart SDK 3.13.2 or later
- Platform tooling for each intended build target

## Getting Started

Install dependencies:

```powershell
flutter pub get
```

Run the app on an available device:

```powershell
flutter run
```

List connected devices when selecting a specific target:

```powershell
flutter devices
flutter run -d <device-id>
```

## Quality Checks

Run static analysis and tests before creating a release:

```powershell
flutter analyze
flutter test
```

## Release Builds

Standard Flutter release commands:

```powershell
flutter build apk --release
flutter build appbundle --release
flutter build web --release
flutter build windows --release
```

PowerShell helpers are also available for versioned Android and Windows builds:

```powershell
./scripts/build-release.ps1 -Target apk
./scripts/build-release.ps1 -Target appbundle
./scripts/build-release.ps1 -Target msix
```

For an Android APK build that first clears common locked build outputs:

```powershell
./scripts/build-apk-release.ps1 -KillFlutterProcesses
```

The app version is defined in `pubspec.yaml` using Flutter's `major.minor.patch+build` format.

## Store Listing

Google Play descriptions are maintained in:

- `store_listing/google_play_short_synopsis.txt`
- `store_listing/google_play_long_synopsis.txt`

## Project Layout

- `lib/main.dart` is the application entry point.
- `lib/app/` contains startup state, splash presentation, and tab composition.
- `lib/features/card_backs/` contains the card-back selection experience.
- `lib/features/five_card/` contains Five Card, shared hand evaluation, computer strategy, chip widgets, and persisted game state.
- `lib/features/draw/` contains the Draw game.
- `lib/features/stud/` contains the shared Stud, Stud7, and multi-street betting controller.
- `lib/features/holdem/` contains the Hold'em game entry point.
- `lib/features/help/` contains in-app guidance.
- `lib/shared/` contains shared card models and presentation widgets.
- `lib/features/information/` contains the top-level Information tab.
- `lib/contact/` contains the reusable contact form and inquiry views.
- `test/shared/` contains focused tests for shared domain behavior.
- `scripts/` contains maintenance, versioning, and release helpers.
- `tool/` contains additional release automation.
- `store_listing/` contains publishing copy for the app stores.
