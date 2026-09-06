import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/enums/collections_call_row_status.dart';
import 'package:daftar/domain/value_objects/collections_call_progress.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_call_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows calling progress and latest row status word', (tester) async {
    const progress = CollectionsCallProgress(
      results: [
        CollectionsCallProgressRow(
          contactId: 'a',
          status: CollectionsCallRowStatus.completed,
        ),
        CollectionsCallProgressRow(
          contactId: 'b',
          status: CollectionsCallRowStatus.ringing,
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CollectionsCallProgressBar(progress: progress),
        ),
      ),
    );

    expect(find.text('Calling 2 of 2'), findsOneWidget);
    expect(find.text('ringing'), findsOneWidget);
    expect(find.textContaining('delivered'), findsNothing);
    expect(find.textContaining('paid'), findsNothing);
  });
}
