import 'package:flutter/material.dart';

import '../../contact/contact_page.dart';
import '../../contact/submissions_csv_page.dart';

class InformationPage extends StatelessWidget {
  const InformationPage({super.key});

  static final Uri _contactUri = Uri.parse(
    'https://stefanronnkvist.com/contact.php',
  );

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: ColoredBox(
        color: colors.surface,
        child: Column(
          children: [
            Material(
              color: colors.surfaceContainer,
              child: const TabBar(
                tabs: [
                  Tab(
                    icon: Icon(Icons.contact_support_outlined),
                    text: 'Contact',
                  ),
                  Tab(icon: Icon(Icons.inbox_outlined), text: 'Inquiries'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ContactPage(
                    serverUri: _contactUri,
                    showAppBar: false,
                    wrapInScaffold: false,
                  ),
                  const SubmissionsCsvCardsView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
