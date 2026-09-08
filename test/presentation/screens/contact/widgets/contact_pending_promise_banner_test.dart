import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/entities/collection_promise.dart';
import 'package:daftar/domain/enums/collection_promise_status.dart';
import 'package:daftar/presentation/providers/contact_providers.dart';
import 'package:daftar/presentation/screens/contact/widgets/contact_pending_promise_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows pending promise amount, date, and update status', (
    tester,
  ) async {
    const contactId = 'contact-promise';
    final promise = CollectionPromise(
      id: 'promise-1',
      contactId: contactId,
      runId: 'run-1',
      amountMinor: 1500,
      currencyCode: 'USD',
      promisedDate: '2026-09-10',
      status: CollectionPromiseStatus.pending,
      updatedAt: DateTime.utc(2026, 9, 6),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pendingCollectionPromisesProvider(contactId).overrideWith(
            (ref) => Stream.value([promise]),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CustomScrollView(
            slivers: [
              ContactPendingPromiseBanner(
                contactId: contactId,
                contactName: 'Mohamed',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Promised'), findsOneWidget);
    expect(find.textContaining('15.00'), findsOneWidget);
    expect(find.text('Update status'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.textContaining('does not write money'), findsOneWidget);
    expect(find.textContaining('delivered'), findsNothing);
    expect(find.textContaining('paid'), findsNothing);
  });

  testWidgets('hides when no pending promises', (tester) async {
    const contactId = 'contact-empty';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pendingCollectionPromisesProvider(contactId).overrideWith(
            (ref) => Stream.value(const <CollectionPromise>[]),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CustomScrollView(
            slivers: [
              ContactPendingPromiseBanner(
                contactId: contactId,
                contactName: 'Mohamed',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Promised'), findsNothing);
    expect(find.text('Update status'), findsNothing);
  });
}
