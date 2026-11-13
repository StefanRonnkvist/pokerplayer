import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playpoker/features/help/help_page.dart';

void main() {
  testWidgets('documents every app tab and shared game settings', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 3000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HelpPage())),
    );

    for (final title in [
      'Card Backs',
      'Five Card',
      'Draw',
      'Stud',
      'Stud7',
      "Hold'em",
      'Settings and Betting',
      'Teach Mode',
      'Virtual Chips and Progress',
      'Information',
      'Help',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.textContaining('pre-flop'), findsOneWidget);
    expect(find.textContaining('Player 1 is you'), findsOneWidget);
    expect(find.textContaining('computer play continues'), findsOneWidget);
    expect(find.textContaining('Reset funds to defaults'), findsOneWidget);
    expect(
      find.textContaining('Check passes without wagering'),
      findsOneWidget,
    );
    expect(
      find.textContaining('configured ante rather than blinds'),
      findsOneWidget,
    );
    expect(find.textContaining('guidance, not a guarantee'), findsOneWidget);
    expect(
      find.textContaining('package, version, platform, orientation'),
      findsOneWidget,
    );
    expect(find.textContaining('no real-money wagering'), findsNWidgets(2));
  });
}
