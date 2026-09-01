import 'dart:developer' as developer;
import 'dart:io';

import 'package:daftar/application/activation/activate_code_use_case.dart';
import 'package:daftar/application/agent/agent_confirm_gate.dart';
import 'package:daftar/application/agent/answer_ask_books_use_case.dart';
import 'package:daftar/application/agent/append_agent_turn_use_case.dart';
import 'package:daftar/application/agent/append_day_journal_entry_use_case.dart';
import 'package:daftar/application/agent/cancel_agent_proposal_use_case.dart';
import 'package:daftar/application/agent/commit_agent_proposal_use_case.dart';
import 'package:daftar/application/agent/complete_agent_session_use_case.dart';
import 'package:daftar/application/agent/enqueue_agent_outbox_item_use_case.dart';
import 'package:daftar/application/agent/get_closing_day_summary_use_case.dart';
import 'package:daftar/application/agent/hydrate_agent_id_token_use_case.dart';
import 'package:daftar/application/agent/list_agent_contact_candidates_use_case.dart';
import 'package:daftar/application/agent/list_day_journal_entries_use_case.dart';
import 'package:daftar/application/agent/list_pending_agent_outbox_use_case.dart';
import 'package:daftar/application/agent/resolve_agent_contact_use_case.dart';
import 'package:daftar/application/agent/resolve_contact_hint_use_case.dart';
import 'package:daftar/application/agent/run_closing_agent_turn_use_case.dart';
import 'package:daftar/application/agent/start_agent_session_use_case.dart';
import 'package:daftar/application/agent/synthesize_agent_speech_use_case.dart';
import 'package:daftar/application/agent/update_agent_turn_confirm_state_use_case.dart';
import 'package:daftar/application/ai/get_active_voice_context_use_case.dart';
import 'package:daftar/application/auth/finalize_drive_credentials_use_case.dart';
import 'package:daftar/application/auth/handle_google_account_change_use_case.dart';
import 'package:daftar/application/auth/reconcile_drift_identity_use_case.dart';
import 'package:daftar/application/auth/session_bootstrap_coordinator.dart';
import 'package:daftar/application/auth/session_bootstrap_use_case.dart';
import 'package:daftar/application/backup/notify_auto_backup_outcome_use_case.dart';
import 'package:daftar/application/contact/check_credit_limit_use_case.dart';
import 'package:daftar/application/contact/create_contact_use_case.dart';
import 'package:daftar/application/contact/delete_contact_use_case.dart';
import 'package:daftar/application/contact/get_collections_candidates_use_case.dart';
import 'package:daftar/application/contact/get_contact_by_id_use_case.dart';
import 'package:daftar/application/contact/get_contact_summaries_use_case.dart';
import 'package:daftar/application/contact/get_contacts_use_case.dart';
import 'package:daftar/application/contact/get_reminder_eligible_contacts_use_case.dart';
import 'package:daftar/application/contact/prepare_contact_statement_use_case.dart';
import 'package:daftar/application/contact/restore_contact_use_case.dart';
import 'package:daftar/application/contact/search_contacts_use_case.dart';
import 'package:daftar/application/contact/update_contact_use_case.dart';
import 'package:daftar/application/contact/watch_contact_count_use_case.dart';
import 'package:daftar/application/import/import_csv_use_case.dart';
import 'package:daftar/application/ledger/archive_ledger_use_case.dart';
import 'package:daftar/application/ledger/create_ledger_use_case.dart';
import 'package:daftar/application/ledger/delete_ledger_use_case.dart';
import 'package:daftar/application/ledger/get_archived_ledgers_use_case.dart';
import 'package:daftar/application/ledger/get_ledger_balance_summary_use_case.dart';
import 'package:daftar/application/ledger/get_ledger_by_id_use_case.dart';
import 'package:daftar/application/ledger/get_ledgers_use_case.dart';
import 'package:daftar/application/ledger/prepare_ledger_summary_export_use_case.dart';
import 'package:daftar/application/ledger/preview_carry_forward_use_case.dart';
import 'package:daftar/application/ledger/restore_ledger_use_case.dart';
import 'package:daftar/application/ledger/unarchive_ledger_use_case.dart';
import 'package:daftar/application/ledger/update_ledger_use_case.dart';
import 'package:daftar/application/ledger/watch_ledger_balance_summary_use_case.dart';
import 'package:daftar/application/merchant/clear_merchant_logo_use_case.dart';
import 'package:daftar/application/merchant/resolve_pdf_merchant_profile_use_case.dart';
import 'package:daftar/application/merchant/set_merchant_logo_use_case.dart';
import 'package:daftar/application/merchant/update_merchant_profile_use_case.dart';
import 'package:daftar/application/settings/complete_onboarding_use_case.dart';
import 'package:daftar/application/settings/mark_agent_fab_tip_seen_use_case.dart';
import 'package:daftar/application/settings/set_demo_architecture_hud_use_case.dart';
import 'package:daftar/application/transaction/add_transaction_use_case.dart';
import 'package:daftar/application/transaction/delete_transaction_use_case.dart';
import 'package:daftar/application/transaction/get_all_transactions_for_contact_use_case.dart';
import 'package:daftar/application/transaction/get_autocomplete_suggestions_use_case.dart';
import 'package:daftar/application/transaction/get_transactions_use_case.dart';
import 'package:daftar/application/transaction/restore_transaction_use_case.dart';
import 'package:daftar/application/transaction/update_transaction_use_case.dart';
import 'package:daftar/application/workspace/activate_archived_imports_use_case.dart';
import 'package:daftar/core/debug/agent_debug_log.dart';
import 'package:daftar/core/l10n/backup_auto_notification_strings.dart';
import 'package:daftar/core/services/auth_session_store.dart';
import 'package:daftar/core/services/sync_token_store.dart';
import 'package:daftar/data/datasources/local/activation_secure_storage_ds.dart';
import 'package:daftar/data/datasources/local/agent_outbox_local_ds.dart';
import 'package:daftar/data/datasources/local/agent_session_local_ds.dart';
import 'package:daftar/data/datasources/local/agent_turn_local_ds.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/backup_local_ds.dart';
import 'package:daftar/data/datasources/local/backup_queue_local_ds.dart';
import 'package:daftar/data/datasources/local/balance_local_ds.dart';
import 'package:daftar/data/datasources/local/collections_send_queue_local_ds.dart';
import 'package:daftar/data/datasources/local/contact_local_ds.dart';
import 'package:daftar/data/datasources/local/day_journal_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/datasources/local/ledger_local_ds.dart';
import 'package:daftar/data/datasources/local/merchant_profile_local_ds.dart';
import 'package:daftar/data/datasources/local/merge_engine_local_ds.dart';
import 'package:daftar/data/datasources/local/settings_local_ds.dart';
import 'package:daftar/data/datasources/local/transaction_local_ds.dart';
import 'package:daftar/data/datasources/remote/activation_api_ds.dart';
import 'package:daftar/data/datasources/remote/auth_silent_sign_in_gateway_impl.dart';
import 'package:daftar/data/datasources/remote/closing_agent_remote_ds.dart';
import 'package:daftar/data/datasources/remote/drive_offline_grant_ds.dart';
import 'package:daftar/data/datasources/remote/google_auth_ds.dart';
import 'package:daftar/data/datasources/remote/supabase_auth_bridge_ds.dart';
import 'package:daftar/data/repositories/activation_repository_impl.dart';
import 'package:daftar/data/repositories/agent_outbox_repository_impl.dart';
import 'package:daftar/data/repositories/agent_session_repository_impl.dart';
import 'package:daftar/data/repositories/agent_speech_repository_impl.dart';
import 'package:daftar/data/repositories/agent_turn_repository_impl.dart';
import 'package:daftar/data/repositories/auth_repository_impl.dart';
import 'package:daftar/data/repositories/balance_recalculation_service.dart';
import 'package:daftar/data/repositories/balance_repository_impl.dart';
import 'package:daftar/data/repositories/bulk_write_repository_impl.dart';
import 'package:daftar/data/repositories/bulk_write_service.dart';
import 'package:daftar/data/repositories/closing_agent_runtime_repository_impl.dart';
import 'package:daftar/data/repositories/collections_send_queue_repository_impl.dart';
import 'package:daftar/data/repositories/contact_repository_impl.dart';
import 'package:daftar/data/repositories/day_journal_repository_impl.dart';
import 'package:daftar/data/repositories/google_identity_repository_impl.dart';
import 'package:daftar/data/repositories/ledger_repository_impl.dart';
import 'package:daftar/data/repositories/merchant_profile_repository_impl.dart';
import 'package:daftar/data/repositories/merge_engine_repository_impl.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/data/repositories/settings_repository_impl.dart';
import 'package:daftar/data/repositories/transaction_repository_impl.dart';
import 'package:daftar/data/services/backup_notification_client.dart';
import 'package:daftar/data/services/notification_service_impl.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/agent_outbox_repository.dart';
import 'package:daftar/domain/repositories/agent_session_repository.dart';
import 'package:daftar/domain/repositories/agent_speech_repository.dart';
import 'package:daftar/domain/repositories/agent_turn_repository.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/repositories/balance_repository.dart';
import 'package:daftar/domain/repositories/bulk_write_repository.dart';
import 'package:daftar/domain/repositories/closing_agent_runtime_repository.dart';
import 'package:daftar/domain/repositories/collections_send_queue_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/day_journal_repository.dart';
import 'package:daftar/domain/repositories/google_identity_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/repositories/merchant_profile_repository.dart';
import 'package:daftar/domain/repositories/merge_engine_repository.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:daftar/domain/services/auth_silent_sign_in_gateway.dart';
import 'package:daftar/domain/services/notification_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'core_providers.g.dart';

/// Provides the application database instance.
///
/// The production app overrides this provider in `main.dart` after
/// `bootstrap()` opens the on-disk database.
@Riverpod(keepAlive: true)
db.AppDatabase appDatabase(Ref ref) {
  throw UnimplementedError(
    'appDatabaseProvider must be overridden before the app starts.',
  );
}

/// Provides the application documents directory used for on-disk data.
///
/// Integration tests can override this with a temporary directory to keep
/// backup and restore flows isolated from the real device documents folder.
@Riverpod(keepAlive: true)
Future<Directory> appDocumentsDirectory(Ref ref) async {
  return getApplicationDocumentsDirectory();
}

/// Controls whether Android public-download export is enabled.
///
/// Tests can override this to `false` to bypass MediaStore and permission
/// behavior while still exercising the backup pipeline end-to-end.
@Riverpod(keepAlive: true)
bool backupPublicExportEnabled(Ref ref) {
  return true;
}

/// Provides the audit log local data source.
@Riverpod(keepAlive: true)
AuditLogLocalDataSource auditLogLocalDataSource(Ref ref) {
  return AuditLogLocalDataSource(ref.watch(appDatabaseProvider));
}

/// Provides the ledger local data source.
@Riverpod(keepAlive: true)
LedgerLocalDataSource ledgerLocalDataSource(Ref ref) {
  return LedgerLocalDataSource(ref.watch(appDatabaseProvider));
}

/// Provides the contact local data source.
@Riverpod(keepAlive: true)
ContactLocalDataSource contactLocalDataSource(Ref ref) {
  return ContactLocalDataSource(ref.watch(appDatabaseProvider));
}

/// Provides the transaction local data source.
@Riverpod(keepAlive: true)
TransactionLocalDataSource transactionLocalDataSource(Ref ref) {
  return TransactionLocalDataSource(ref.watch(appDatabaseProvider));
}

/// Provides the balance local data source.
@Riverpod(keepAlive: true)
BalanceLocalDataSource balanceLocalDataSource(Ref ref) {
  return BalanceLocalDataSource(ref.watch(appDatabaseProvider));
}

/// Provides the settings local data source.
@Riverpod(keepAlive: true)
SettingsLocalDataSource settingsLocalDataSource(Ref ref) {
  return SettingsLocalDataSource(ref.watch(appDatabaseProvider));
}

/// Provides the backup local data source.
@Riverpod(keepAlive: true)
BackupLocalDs backupLocalDs(Ref ref) {
  return BackupLocalDs(
    ref.watch(appDatabaseProvider),
    documentsDirectoryResolver: () =>
        ref.read(appDocumentsDirectoryProvider.future),
    publicExportEnabledResolver: () =>
        ref.read(backupPublicExportEnabledProvider),
  );
}

/// Provides the Drive backup upload queue local data source.
@Riverpod(keepAlive: true)
BackupQueueLocalDs backupQueueLocalDs(Ref ref) {
  return BackupQueueLocalDs(ref.watch(appDatabaseProvider));
}

/// Persists the Auth V2 secure session bundle.
@Riverpod(keepAlive: true)
AuthSessionStore authSessionStore(Ref ref) {
  return AuthSessionStore();
}

/// Google Sign-In SDK adapter (singleton per provider scope).
@Riverpod(keepAlive: true)
GoogleAuthDs googleAuthDs(Ref ref) {
  final googleAuthDs = GoogleAuthDs(
    authSessionStore: ref.watch(authSessionStoreProvider),
  );
  ref.onDispose(googleAuthDs.dispose);
  return googleAuthDs;
}

/// Silent sign-in gateway for cold-start session bootstrap.
@Riverpod(keepAlive: true)
AuthSilentSignInGateway authSilentSignInGateway(Ref ref) {
  return AuthSilentSignInGatewayImpl(ref.watch(googleAuthDsProvider));
}

/// Reconciles Drift Google identity fields from the secure session bundle.
@Riverpod(keepAlive: true)
ReconcileDriftIdentityUseCase reconcileDriftIdentityUseCase(Ref ref) {
  return ReconcileDriftIdentityUseCase(
    ref.watch(settingsRepositoryProvider),
  );
}

/// Cold-start session bootstrap use case.
@Riverpod(keepAlive: true)
SessionBootstrapUseCase sessionBootstrapUseCase(Ref ref) {
  return SessionBootstrapUseCase(
    ref.watch(authSessionStoreProvider),
    ref.watch(settingsRepositoryProvider),
    ref.watch(authSilentSignInGatewayProvider),
    ref.watch(reconcileDriftIdentityUseCaseProvider),
  );
}

/// Single-flight coordinator for cold-start session bootstrap.
@Riverpod(keepAlive: true)
SessionBootstrapCoordinator sessionBootstrapCoordinator(Ref ref) {
  return SessionBootstrapCoordinator(
    ref.watch(sessionBootstrapUseCaseProvider),
  );
}

/// Post-bootstrap silent Drive credential hydration at app launch.
@Riverpod(keepAlive: true)
FinalizeDriveCredentialsUseCase finalizeDriveCredentialsUseCase(Ref ref) {
  return FinalizeDriveCredentialsUseCase(
    ref.watch(authSessionStoreProvider),
    ref.watch(authSilentSignInGatewayProvider),
  );
}

/// Purges Drive linkage when the signed-in Google account changes.
@Riverpod(keepAlive: true)
GoogleIdentityRepository googleIdentityRepository(Ref ref) {
  return GoogleIdentityRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    backupLocalDs: ref.watch(backupLocalDsProvider),
    backupQueueLocalDs: ref.watch(backupQueueLocalDsProvider),
    auditLogLocalDataSource: ref.watch(auditLogLocalDataSourceProvider),
  );
}

/// Account-switch ceremony (cancel WM → delete bundle → purge Drive state).
@Riverpod(keepAlive: true)
HandleGoogleAccountChangeUseCase handleGoogleAccountChangeUseCase(Ref ref) {
  return HandleGoogleAccountChangeUseCase(
    ref.watch(googleIdentityRepositoryProvider),
    ref.watch(authSessionStoreProvider),
  );
}

/// PKCE offline-grant acquirer (interactive Drive refresh-token consent).
@Riverpod(keepAlive: true)
DriveOfflineGrantDs driveOfflineGrantDs(Ref ref) {
  return DriveOfflineGrantDs();
}

/// Google-backed [AuthRepository] (Auth V2).
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(
    googleAuthDs: ref.watch(googleAuthDsProvider),
    authSessionStore: ref.watch(authSessionStoreProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
    reconcileDriftIdentityUseCase: ref.watch(
      reconcileDriftIdentityUseCaseProvider,
    ),
    handleGoogleAccountChangeUseCase: ref.watch(
      handleGoogleAccountChangeUseCaseProvider,
    ),
    sessionBootstrapCoordinator: ref.watch(sessionBootstrapCoordinatorProvider),
    backupLocalDs: ref.watch(backupLocalDsProvider),
    backupQueueLocalDs: ref.watch(backupQueueLocalDsProvider),
    auditLogLocalDataSource: ref.watch(auditLogLocalDataSourceProvider),
    driveOfflineGrantDs: ref.watch(driveOfflineGrantDsProvider),
    supabaseAuthBridgeDs: ref.watch(supabaseAuthBridgeDsProvider),
  );
}

/// Shared HTTP client for Edge Function calls (activation, etc.).
@Riverpod(keepAlive: true)
Dio dioClient(Ref ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  // Temporary LAN diagnostics: absolute target URL must be the Mac's current
  // Wi-Fi IP (not 127.0.0.1). Auth headers are intentionally never logged.
  if (kDebugMode) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          developer.log(
            '${options.method} ${options.uri} '
            'payload=${_syncHttpPayloadSummary(options.data)}',
            name: 'SyncHttp',
          );
          // #region agent log
          AgentDebugLog.write(
            location: 'core_providers.dart:dioClient',
            message: 'sync_http_request',
            hypothesisId: 'H3-dio-target',
            data: <String, Object?>{
              'method': options.method,
              'uri': options.uri.toString(),
              'payload': _syncHttpPayloadSummary(options.data),
            },
          );
          // #endregion
          handler.next(options);
        },
        onError: (error, handler) {
          developer.log(
            '${error.type} ${error.requestOptions.uri} ${error.message}',
            name: 'SyncHttp',
            error: error,
          );
          // #region agent log
          AgentDebugLog.write(
            location: 'core_providers.dart:dioClient',
            message: 'sync_http_error',
            hypothesisId: 'H3-dio-target',
            data: <String, Object?>{
              'dioType': error.type.name,
              'uri': error.requestOptions.uri.toString(),
              'statusCode': error.response?.statusCode,
            },
          );
          // #endregion
          handler.next(error);
        },
      ),
    );
  }

  return dio;
}

String _syncHttpPayloadSummary(Object? data) {
  if (data == null) {
    return 'none';
  }
  if (data is Map) {
    final ops = data['ops'];
    if (ops is List) {
      return 'ops=${ops.length}';
    }
    return 'map_keys=${data.length}';
  }
  if (data is List) {
    return 'list_len=${data.length}';
  }
  if (data is String) {
    return 'bytes=${data.length}';
  }
  return 'type=${data.runtimeType}';
}

/// Remote activation Edge Function client.
@Riverpod(keepAlive: true)
ActivationApiDs activationApiDs(Ref ref) {
  return ActivationApiDs(dio: ref.watch(dioClientProvider));
}

/// Secure storage for signed entitlement tokens.
@Riverpod(keepAlive: true)
ActivationSecureStorageDs activationSecureStorageDs(Ref ref) {
  return ActivationSecureStorageDs();
}

/// Entitlement / activation repository.
@Riverpod(keepAlive: true)
ActivationRepository activationRepository(Ref ref) {
  return ActivationRepositoryImpl(
    activationApiDs: ref.watch(activationApiDsProvider),
    secureStorageDs: ref.watch(activationSecureStorageDsProvider),
  );
}

/// Redeems prepaid activation codes.
@Riverpod(keepAlive: true)
ActivateCodeUseCase activateCodeUseCase(Ref ref) {
  return ActivateCodeUseCase(ref.watch(activationRepositoryProvider));
}

/// Persists the custom Supabase sync JWT (Stage 8.3).
@Riverpod(keepAlive: true)
SyncTokenStore syncTokenStore(Ref ref) {
  return SyncTokenStore();
}

/// Auth bridge: exchanges Google ID Token for a custom sync JWT
/// via the `verify-google-token` Edge Function (Stage 8.2).
@Riverpod(keepAlive: true)
SupabaseAuthBridgeDs supabaseAuthBridgeDs(Ref ref) {
  return SupabaseAuthBridgeDs(
    dio: ref.watch(dioClientProvider),
    syncTokenStore: ref.watch(syncTokenStoreProvider),
  );
}

/// Merge engine local data source (Stage 8.3).
@Riverpod(keepAlive: true)
MergeEngineLocalDs mergeEngineLocalDs(Ref ref) {
  return MergeEngineLocalDs(
    ref.watch(appDatabaseProvider),
    localDeviceId: repositoryDeviceId,
  );
}

/// Merge engine repository (Stage 8.3).
@Riverpod(keepAlive: true)
MergeEngineRepository mergeEngineRepository(Ref ref) {
  return MergeEngineRepositoryImpl(
    mergeEngineDs: ref.watch(mergeEngineLocalDsProvider),
    auditLogDs: ref.watch(auditLogLocalDataSourceProvider),
    syncTokenStore: ref.watch(syncTokenStoreProvider),
  );
}

/// Provides the merchant profile local data source.
@Riverpod(keepAlive: true)
MerchantProfileLocalDs merchantProfileLocalDs(Ref ref) {
  return MerchantProfileLocalDs(ref.watch(appDatabaseProvider));
}

/// Provides the ledger repository.
@Riverpod(keepAlive: true)
LedgerRepository ledgerRepository(Ref ref) {
  return LedgerRepositoryImpl(
    ledgerLocalDataSource: ref.watch(ledgerLocalDataSourceProvider),
    contactLocalDataSource: ref.watch(contactLocalDataSourceProvider),
    transactionLocalDataSource: ref.watch(transactionLocalDataSourceProvider),
    balanceLocalDataSource: ref.watch(balanceLocalDataSourceProvider),
    auditLogLocalDataSource: ref.watch(auditLogLocalDataSourceProvider),
  );
}

/// Provides the contact repository.
@Riverpod(keepAlive: true)
ContactRepository contactRepository(Ref ref) {
  return ContactRepositoryImpl(
    contactLocalDataSource: ref.watch(contactLocalDataSourceProvider),
    transactionLocalDataSource: ref.watch(transactionLocalDataSourceProvider),
    balanceLocalDataSource: ref.watch(balanceLocalDataSourceProvider),
    auditLogLocalDataSource: ref.watch(auditLogLocalDataSourceProvider),
  );
}

/// Provides the balance repository.
@Riverpod(keepAlive: true)
BalanceRepository balanceRepository(Ref ref) {
  return BalanceRepositoryImpl(
    balanceLocalDataSource: ref.watch(balanceLocalDataSourceProvider),
    transactionLocalDataSource: ref.watch(transactionLocalDataSourceProvider),
  );
}

/// Provides the transaction repository.
@Riverpod(keepAlive: true)
TransactionRepository transactionRepository(Ref ref) {
  return TransactionRepositoryImpl(
    transactionLocalDataSource: ref.watch(transactionLocalDataSourceProvider),
    balanceLocalDataSource: ref.watch(balanceLocalDataSourceProvider),
    auditLogLocalDataSource: ref.watch(auditLogLocalDataSourceProvider),
  );
}

/// Orchestrates atomic bulk inserts for CSV import and similar batch writes.
@Riverpod(keepAlive: true)
BulkWriteService bulkWriteService(Ref ref) {
  return BulkWriteService(
    database: ref.watch(appDatabaseProvider),
    contactLocalDataSource: ref.watch(contactLocalDataSourceProvider),
    transactionLocalDataSource: ref.watch(transactionLocalDataSourceProvider),
    auditLogLocalDataSource: ref.watch(auditLogLocalDataSourceProvider),
    balanceRecalculationService: BalanceRecalculationService(
      database: ref.watch(appDatabaseProvider),
      balanceLocalDataSource: ref.watch(balanceLocalDataSourceProvider),
    ),
  );
}

/// Provides the bulk write repository.
@Riverpod(keepAlive: true)
BulkWriteRepository bulkWriteRepository(Ref ref) {
  return BulkWriteRepositoryImpl(
    bulkWriteService: ref.watch(bulkWriteServiceProvider),
  );
}

/// Provides the settings repository.
@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) {
  return SettingsRepositoryImpl(
    settingsLocalDataSource: ref.watch(settingsLocalDataSourceProvider),
    auditLogLocalDataSource: ref.watch(auditLogLocalDataSourceProvider),
  );
}

/// Persists first-run onboarding completion.
@Riverpod(keepAlive: true)
CompleteOnboardingUseCase completeOnboardingUseCase(Ref ref) {
  return CompleteOnboardingUseCase(ref.watch(settingsRepositoryProvider));
}

/// Persists that the Closing Agent FAB tip sheet has been shown.
@Riverpod(keepAlive: true)
MarkAgentFabTipSeenUseCase markAgentFabTipSeenUseCase(Ref ref) {
  return MarkAgentFabTipSeenUseCase(ref.watch(settingsRepositoryProvider));
}

/// Persists the contest Architecture HUD overlay toggle.
@Riverpod(keepAlive: true)
SetDemoArchitectureHudUseCase setDemoArchitectureHudUseCase(Ref ref) {
  return SetDemoArchitectureHudUseCase(ref.watch(settingsRepositoryProvider));
}

/// Provides the merchant profile repository.
@Riverpod(keepAlive: true)
MerchantProfileRepository merchantProfileRepository(Ref ref) {
  return MerchantProfileRepositoryImpl(
    merchantProfileLocalDs: ref.watch(merchantProfileLocalDsProvider),
    documentsDirectoryResolver: () =>
        ref.read(appDocumentsDirectoryProvider.future),
  );
}

/// Provides the update-merchant-profile use case.
@Riverpod(keepAlive: true)
UpdateMerchantProfileUseCase updateMerchantProfileUseCase(Ref ref) {
  return UpdateMerchantProfileUseCase(
    ref.watch(merchantProfileRepositoryProvider),
  );
}

/// Provides the set-merchant-logo use case.
@Riverpod(keepAlive: true)
SetMerchantLogoUseCase setMerchantLogoUseCase(Ref ref) {
  return SetMerchantLogoUseCase(
    ref.watch(merchantProfileRepositoryProvider),
    ref.watch(activationRepositoryProvider),
    () => ref.read(appDocumentsDirectoryProvider.future),
  );
}

/// Provides the clear-merchant-logo use case.
@Riverpod(keepAlive: true)
ClearMerchantLogoUseCase clearMerchantLogoUseCase(Ref ref) {
  return ClearMerchantLogoUseCase(
    ref.watch(merchantProfileRepositoryProvider),
    ref.watch(activationRepositoryProvider),
  );
}

/// Provides the PDF export merchant-profile resolver (tier-gated branding).
@Riverpod(keepAlive: true)
ResolvePdfMerchantProfileUseCase resolvePdfMerchantProfileUseCase(Ref ref) {
  return ResolvePdfMerchantProfileUseCase(
    ref.watch(merchantProfileRepositoryProvider),
    ref.watch(activationRepositoryProvider),
  );
}

/// Streams the current application settings.
@Riverpod(keepAlive: true)
Stream<AppSettings> appSettings(Ref ref) {
  return ref.watch(settingsRepositoryProvider).watchSettings();
}

/// Provides the get-ledgers use case.
@Riverpod(keepAlive: true)
GetLedgersUseCase getLedgersUseCase(Ref ref) {
  return GetLedgersUseCase(ref.watch(ledgerRepositoryProvider));
}

/// Provides the get-ledger-by-id use case.
@Riverpod(keepAlive: true)
GetLedgerByIdUseCase getLedgerByIdUseCase(Ref ref) {
  return GetLedgerByIdUseCase(ref.watch(ledgerRepositoryProvider));
}

/// Provides the create-ledger use case.
@Riverpod(keepAlive: true)
CreateLedgerUseCase createLedgerUseCase(Ref ref) {
  return CreateLedgerUseCase(
    ref.watch(ledgerRepositoryProvider),
    ref.watch(activationRepositoryProvider),
  );
}

/// Provides the update-ledger use case.
@Riverpod(keepAlive: true)
UpdateLedgerUseCase updateLedgerUseCase(Ref ref) {
  return UpdateLedgerUseCase(ref.watch(ledgerRepositoryProvider));
}

/// Provides the delete-ledger use case.
@Riverpod(keepAlive: true)
DeleteLedgerUseCase deleteLedgerUseCase(Ref ref) {
  return DeleteLedgerUseCase(ref.watch(ledgerRepositoryProvider));
}

/// Loads ledger metadata, contacts, and balances for summary PDF export.
final prepareLedgerSummaryExportUseCaseProvider =
    Provider<PrepareLedgerSummaryExportUseCase>(
      (ref) => PrepareLedgerSummaryExportUseCase(
        ref.watch(ledgerRepositoryProvider),
        ref.watch(contactRepositoryProvider),
        ref.watch(balanceRepositoryProvider),
      ),
    );

/// Provides the restore-ledger use case.
@Riverpod(keepAlive: true)
RestoreLedgerUseCase restoreLedgerUseCase(Ref ref) {
  return RestoreLedgerUseCase(ref.watch(ledgerRepositoryProvider));
}

/// Provides the get-archived-ledgers use case.
@Riverpod(keepAlive: true)
GetArchivedLedgersUseCase getArchivedLedgersUseCase(Ref ref) {
  return GetArchivedLedgersUseCase(ref.watch(ledgerRepositoryProvider));
}

/// Provides the archive-ledger use case.
@Riverpod(keepAlive: true)
ArchiveLedgerUseCase archiveLedgerUseCase(Ref ref) {
  return ArchiveLedgerUseCase(
    ref.watch(ledgerRepositoryProvider),
    ref.watch(contactRepositoryProvider),
    ref.watch(transactionRepositoryProvider),
    ref.watch(activationRepositoryProvider),
  );
}

/// Provides the preview-carry-forward use case.
@Riverpod(keepAlive: true)
PreviewCarryForwardUseCase previewCarryForwardUseCase(Ref ref) {
  return PreviewCarryForwardUseCase(ref.watch(ledgerRepositoryProvider));
}

/// Provides the unarchive-ledger use case.
@Riverpod(keepAlive: true)
UnarchiveLedgerUseCase unarchiveLedgerUseCase(Ref ref) {
  return UnarchiveLedgerUseCase(
    ref.watch(ledgerRepositoryProvider),
    ref.watch(activationRepositoryProvider),
  );
}

/// Provides the get-contacts use case.
@Riverpod(keepAlive: true)
GetContactsUseCase getContactsUseCase(Ref ref) {
  return GetContactsUseCase(ref.watch(contactRepositoryProvider));
}

/// Provides the get-contact-summaries use case.
@Riverpod(keepAlive: true)
GetContactSummariesUseCase getContactSummariesUseCase(Ref ref) {
  return GetContactSummariesUseCase(ref.watch(contactRepositoryProvider));
}

/// Provides the watch-contact-count use case.
@Riverpod(keepAlive: true)
WatchContactCountUseCase watchContactCountUseCase(Ref ref) {
  return WatchContactCountUseCase(ref.watch(contactRepositoryProvider));
}

/// Provides the get-contact-by-id use case.
@Riverpod(keepAlive: true)
GetContactByIdUseCase getContactByIdUseCase(Ref ref) {
  return GetContactByIdUseCase(ref.watch(contactRepositoryProvider));
}

/// Drift inputs for a contact statement PDF (no PDF bytes).
@Riverpod(keepAlive: true)
PrepareContactStatementUseCase prepareContactStatementUseCase(Ref ref) {
  return PrepareContactStatementUseCase(
    getContactByIdUseCase: ref.watch(getContactByIdUseCaseProvider),
    getAllTransactionsForContactUseCase: ref.watch(
      getAllTransactionsForContactUseCaseProvider,
    ),
    balanceRepository: ref.watch(balanceRepositoryProvider),
  );
}

/// Provides the search-contacts use case.
@Riverpod(keepAlive: true)
SearchContactsUseCase searchContactsUseCase(Ref ref) {
  return SearchContactsUseCase(ref.watch(contactRepositoryProvider));
}

/// Phone-only reminder eligibility (Stage 3.2 still uses this as the first gate).
@Riverpod(keepAlive: true)
GetReminderEligibleContactsUseCase getReminderEligibleContactsUseCase(Ref ref) {
  return GetReminderEligibleContactsUseCase(
    ref.watch(contactRepositoryProvider),
  );
}

/// Device Collections shortlist: phone ∩ overdue + FIFO aging.
@Riverpod(keepAlive: true)
GetCollectionsCandidatesUseCase getCollectionsCandidatesUseCase(Ref ref) {
  return GetCollectionsCandidatesUseCase(
    getReminderEligibleContactsUseCase: ref.watch(
      getReminderEligibleContactsUseCaseProvider,
    ),
    balanceRepository: ref.watch(balanceRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    contactRepository: ref.watch(contactRepositoryProvider),
  );
}

/// Drift `localDay` snapshot for close-the-day (Appendix J.4).
@Riverpod(keepAlive: true)
GetClosingDaySummaryUseCase getClosingDaySummaryUseCase(Ref ref) {
  return GetClosingDaySummaryUseCase(ref.watch(transactionRepositoryProvider));
}

/// Active voice entity context for the composer.
@Riverpod(keepAlive: true)
GetActiveVoiceContextUseCase getActiveVoiceContextUseCase(Ref ref) {
  return GetActiveVoiceContextUseCase(ref.watch(contactRepositoryProvider));
}

/// Provides the create-contact use case.
@Riverpod(keepAlive: true)
CreateContactUseCase createContactUseCase(Ref ref) {
  return CreateContactUseCase(
    ref.watch(contactRepositoryProvider),
    ref.watch(ledgerRepositoryProvider),
    ref.watch(activationRepositoryProvider),
  );
}

/// Provides the update-contact use case.
@Riverpod(keepAlive: true)
UpdateContactUseCase updateContactUseCase(Ref ref) {
  return UpdateContactUseCase(
    ref.watch(contactRepositoryProvider),
    ref.watch(ledgerRepositoryProvider),
  );
}

/// Provides the delete-contact use case.
@Riverpod(keepAlive: true)
DeleteContactUseCase deleteContactUseCase(Ref ref) {
  return DeleteContactUseCase(
    ref.watch(contactRepositoryProvider),
    ref.watch(ledgerRepositoryProvider),
  );
}

/// Provides the restore-contact use case.
@Riverpod(keepAlive: true)
RestoreContactUseCase restoreContactUseCase(Ref ref) {
  return RestoreContactUseCase(ref.watch(contactRepositoryProvider));
}

/// Provides the credit-limit check use case.
@Riverpod(keepAlive: true)
CheckCreditLimitUseCase checkCreditLimitUseCase(Ref ref) {
  return CheckCreditLimitUseCase(
    ref.watch(contactRepositoryProvider),
    ref.watch(balanceRepositoryProvider),
  );
}

/// Provides the transaction notification service.
@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) {
  return NotificationServiceImpl();
}

/// Posts localized auto-backup notifications (headless + foreground).
@Riverpod(keepAlive: true)
NotifyAutoBackupOutcomeUseCase notifyAutoBackupOutcomeUseCase(Ref ref) {
  return NotifyAutoBackupOutcomeUseCase(
    BackupNotificationClient.instance,
    const BackupAutoNotificationStrings(),
  );
}

/// Provides the add-transaction use case.
@Riverpod(keepAlive: true)
AddTransactionUseCase addTransactionUseCase(Ref ref) {
  return AddTransactionUseCase(
    ref.watch(transactionRepositoryProvider),
    ref.watch(contactRepositoryProvider),
    ref.watch(ledgerRepositoryProvider),
    ref.watch(checkCreditLimitUseCaseProvider),
    ref.watch(activationRepositoryProvider),
  );
}

/// Promotes archived CSV import rows into the live workspace.
@Riverpod(keepAlive: true)
ActivateArchivedImportsUseCase activateArchivedImportsUseCase(Ref ref) {
  return ActivateArchivedImportsUseCase(
    ref.watch(ledgerRepositoryProvider),
    ref.watch(contactRepositoryProvider),
    ref.watch(transactionRepositoryProvider),
    ref.watch(activationRepositoryProvider),
  );
}

/// Imports ledger contacts + transactions from CSV payloads.
@Riverpod(keepAlive: true)
ImportCsvUseCase importCsvUseCase(Ref ref) {
  return ImportCsvUseCase(
    contactRepository: ref.watch(contactRepositoryProvider),
    ledgerRepository: ref.watch(ledgerRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    bulkWriteRepository: ref.watch(bulkWriteRepositoryProvider),
    activationRepository: ref.watch(activationRepositoryProvider),
  );
}

/// Provides the update-transaction use case.
@Riverpod(keepAlive: true)
UpdateTransactionUseCase updateTransactionUseCase(Ref ref) {
  return UpdateTransactionUseCase(
    ref.watch(transactionRepositoryProvider),
    ref.watch(contactRepositoryProvider),
    ref.watch(ledgerRepositoryProvider),
    ref.watch(checkCreditLimitUseCaseProvider),
  );
}

/// Provides the delete-transaction use case.
@Riverpod(keepAlive: true)
DeleteTransactionUseCase deleteTransactionUseCase(Ref ref) {
  return DeleteTransactionUseCase(
    ref.watch(transactionRepositoryProvider),
    ref.watch(contactRepositoryProvider),
    ref.watch(ledgerRepositoryProvider),
  );
}

/// Provides the restore-transaction use case.
@Riverpod(keepAlive: true)
RestoreTransactionUseCase restoreTransactionUseCase(Ref ref) {
  return RestoreTransactionUseCase(ref.watch(transactionRepositoryProvider));
}

/// Provides the get-transactions use case.
@Riverpod(keepAlive: true)
GetTransactionsUseCase getTransactionsUseCase(Ref ref) {
  return GetTransactionsUseCase(ref.watch(transactionRepositoryProvider));
}

/// Provides the all-transactions-for-contact use case.
final getAllTransactionsForContactUseCaseProvider =
    Provider<GetAllTransactionsForContactUseCase>(
      (ref) => GetAllTransactionsForContactUseCase(
        ref.watch(transactionRepositoryProvider),
      ),
    );

/// Provides the ledger balance summary use case.
@Riverpod(keepAlive: true)
GetLedgerBalanceSummaryUseCase getLedgerBalanceSummaryUseCase(Ref ref) {
  return GetLedgerBalanceSummaryUseCase(
    ref.watch(ledgerRepositoryProvider),
    ref.watch(contactRepositoryProvider),
    ref.watch(balanceRepositoryProvider),
  );
}

/// Provides the reactive ledger balance summary stream use case.
@Riverpod(keepAlive: true)
WatchLedgerBalanceSummaryUseCase watchLedgerBalanceSummaryUseCase(Ref ref) {
  return WatchLedgerBalanceSummaryUseCase(
    ref.watch(balanceRepositoryProvider),
  );
}

/// Provides the autocomplete-suggestions use case.
@Riverpod(keepAlive: true)
GetAutocompleteSuggestionsUseCase getAutocompleteSuggestionsUseCase(
  Ref ref,
) {
  return GetAutocompleteSuggestionsUseCase(
    ref.watch(transactionRepositoryProvider),
  );
}

/// Provides the day-journal local data source.
@Riverpod(keepAlive: true)
DayJournalLocalDataSource dayJournalLocalDataSource(Ref ref) {
  return DayJournalLocalDataSource(ref.watch(appDatabaseProvider));
}

/// Provides the agent-session local data source.
@Riverpod(keepAlive: true)
AgentSessionLocalDataSource agentSessionLocalDataSource(Ref ref) {
  return AgentSessionLocalDataSource(ref.watch(appDatabaseProvider));
}

/// Provides the agent-turn local data source.
@Riverpod(keepAlive: true)
AgentTurnLocalDataSource agentTurnLocalDataSource(Ref ref) {
  return AgentTurnLocalDataSource(ref.watch(appDatabaseProvider));
}

/// Provides the agent-outbox local data source.
@Riverpod(keepAlive: true)
AgentOutboxLocalDataSource agentOutboxLocalDataSource(Ref ref) {
  return AgentOutboxLocalDataSource(ref.watch(appDatabaseProvider));
}

/// Provides the day-journal repository.
@Riverpod(keepAlive: true)
DayJournalRepository dayJournalRepository(Ref ref) {
  return DayJournalRepositoryImpl(
    dayJournalLocalDataSource: ref.watch(dayJournalLocalDataSourceProvider),
  );
}

/// Provides the agent-session repository.
@Riverpod(keepAlive: true)
AgentSessionRepository agentSessionRepository(Ref ref) {
  return AgentSessionRepositoryImpl(
    agentSessionLocalDataSource: ref.watch(
      agentSessionLocalDataSourceProvider,
    ),
    auditLogLocalDataSource: ref.watch(auditLogLocalDataSourceProvider),
  );
}

/// Provides the agent-turn repository.
@Riverpod(keepAlive: true)
AgentTurnRepository agentTurnRepository(Ref ref) {
  return AgentTurnRepositoryImpl(
    agentTurnLocalDataSource: ref.watch(agentTurnLocalDataSourceProvider),
    auditLogLocalDataSource: ref.watch(auditLogLocalDataSourceProvider),
  );
}

/// Provides the agent-outbox repository.
@Riverpod(keepAlive: true)
AgentOutboxRepository agentOutboxRepository(Ref ref) {
  return AgentOutboxRepositoryImpl(
    agentOutboxLocalDataSource: ref.watch(agentOutboxLocalDataSourceProvider),
  );
}

/// Provides the Hybrid E send-queue local data source.
@Riverpod(keepAlive: true)
CollectionsSendQueueLocalDataSource collectionsSendQueueLocalDataSource(
  Ref ref,
) {
  return CollectionsSendQueueLocalDataSource(ref.watch(appDatabaseProvider));
}

/// Provides the Hybrid E send-queue repository.
@Riverpod(keepAlive: true)
CollectionsSendQueueRepository collectionsSendQueueRepository(Ref ref) {
  return CollectionsSendQueueRepositoryImpl(
    collectionsSendQueueLocalDataSource: ref.watch(
      collectionsSendQueueLocalDataSourceProvider,
    ),
  );
}

/// Provides the append-day-journal-entry use case.
@Riverpod(keepAlive: true)
AppendDayJournalEntryUseCase appendDayJournalEntryUseCase(Ref ref) {
  return AppendDayJournalEntryUseCase(ref.watch(dayJournalRepositoryProvider));
}

/// Provides the list-day-journal-entries use case.
@Riverpod(keepAlive: true)
ListDayJournalEntriesUseCase listDayJournalEntriesUseCase(Ref ref) {
  return ListDayJournalEntriesUseCase(ref.watch(dayJournalRepositoryProvider));
}

/// Provides the start-agent-session use case.
@Riverpod(keepAlive: true)
StartAgentSessionUseCase startAgentSessionUseCase(Ref ref) {
  return StartAgentSessionUseCase(ref.watch(agentSessionRepositoryProvider));
}

/// Provides the complete-agent-session use case.
@Riverpod(keepAlive: true)
CompleteAgentSessionUseCase completeAgentSessionUseCase(Ref ref) {
  return CompleteAgentSessionUseCase(
    ref.watch(agentSessionRepositoryProvider),
  );
}

/// Provides the append-agent-turn use case.
@Riverpod(keepAlive: true)
AppendAgentTurnUseCase appendAgentTurnUseCase(Ref ref) {
  return AppendAgentTurnUseCase(ref.watch(agentTurnRepositoryProvider));
}

/// Provides the update-agent-turn-confirm-state use case.
@Riverpod(keepAlive: true)
UpdateAgentTurnConfirmStateUseCase updateAgentTurnConfirmStateUseCase(
  Ref ref,
) {
  return UpdateAgentTurnConfirmStateUseCase(
    ref.watch(agentTurnRepositoryProvider),
  );
}

/// Provides the enqueue-agent-outbox-item use case.
@Riverpod(keepAlive: true)
EnqueueAgentOutboxItemUseCase enqueueAgentOutboxItemUseCase(Ref ref) {
  return EnqueueAgentOutboxItemUseCase(
    ref.watch(agentOutboxRepositoryProvider),
  );
}

/// Provides the list-pending-agent-outbox use case.
@Riverpod(keepAlive: true)
ListPendingAgentOutboxUseCase listPendingAgentOutboxUseCase(Ref ref) {
  return ListPendingAgentOutboxUseCase(
    ref.watch(agentOutboxRepositoryProvider),
  );
}

/// Dedicated Dio for Cloud Run ADK (longer receive timeout than sync).
@Riverpod(keepAlive: true)
Dio closingAgentDio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: ClosingAgentConstants.connectTimeout,
      sendTimeout: ClosingAgentConstants.sendTimeout,
      receiveTimeout: ClosingAgentConstants.receiveTimeout,
    ),
  );
  ref.onDispose(dio.close);
  return dio;
}

/// Cloud Run ADK remote data source with Google ID-token auth.
@Riverpod(keepAlive: true)
ClosingAgentRemoteDs closingAgentRemoteDs(Ref ref) {
  return ClosingAgentRemoteDs(
    dio: ref.watch(closingAgentDioProvider),
    readIdToken: ({required allowInteractive}) {
      assert(
        !allowInteractive,
        'Closing Agent interceptor must never open a Google picker',
      );
      return ref.read(googleAuthDsProvider).obtainIdToken();
    },
  );
}

/// User-gesture Google ID token hydrate (agent Send only).
@Riverpod(keepAlive: true)
HydrateAgentIdTokenUseCase hydrateAgentIdTokenUseCase(Ref ref) {
  return HydrateAgentIdTokenUseCase(
    authRepository: ref.watch(authRepositoryProvider),
  );
}

/// Closing Agent runtime repository (Either mapping).
@Riverpod(keepAlive: true)
ClosingAgentRuntimeRepository closingAgentRuntimeRepository(Ref ref) {
  return ClosingAgentRuntimeRepositoryImpl(
    remoteDataSource: ref.watch(closingAgentRemoteDsProvider),
  );
}

/// Chirp 3 HD speech repository (Either mapping).
@Riverpod(keepAlive: true)
AgentSpeechRepository agentSpeechRepository(Ref ref) {
  return AgentSpeechRepositoryImpl(
    remoteDataSource: ref.watch(closingAgentRemoteDsProvider),
  );
}

/// Unary Cloud TTS for agent narrative / confirm / report.
@Riverpod(keepAlive: true)
SynthesizeAgentSpeechUseCase synthesizeAgentSpeechUseCase(Ref ref) {
  return SynthesizeAgentSpeechUseCase(
    repository: ref.watch(agentSpeechRepositoryProvider),
  );
}

/// Process-local confirm-gate (single-flight by proposalId).
@Riverpod(keepAlive: true)
AgentConfirmGate agentConfirmGate(Ref ref) => AgentConfirmGate();

/// Assembles Appendix J context and runs one Cloud Run turn.
@Riverpod(keepAlive: true)
RunClosingAgentTurnUseCase runClosingAgentTurnUseCase(Ref ref) {
  return RunClosingAgentTurnUseCase(
    settingsRepository: ref.watch(settingsRepositoryProvider),
    ledgerRepository: ref.watch(ledgerRepositoryProvider),
    getActiveVoiceContextUseCase: ref.watch(
      getActiveVoiceContextUseCaseProvider,
    ),
    agentSessionRepository: ref.watch(agentSessionRepositoryProvider),
    startAgentSessionUseCase: ref.watch(startAgentSessionUseCaseProvider),
    appendAgentTurnUseCase: ref.watch(appendAgentTurnUseCaseProvider),
    closingAgentRuntimeRepository: ref.watch(
      closingAgentRuntimeRepositoryProvider,
    ),
  );
}

/// Cancel-gate use case (skipped confirm-state; never journals).
@Riverpod(keepAlive: true)
CancelAgentProposalUseCase cancelAgentProposalUseCase(Ref ref) {
  return CancelAgentProposalUseCase(
    confirmGate: ref.watch(agentConfirmGateProvider),
    agentTurnRepository: ref.watch(agentTurnRepositoryProvider),
    updateConfirmStateUseCase: ref.watch(
      updateAgentTurnConfirmStateUseCaseProvider,
    ),
  );
}

/// Resolves a proposal contact from id or a unique name hint.
@Riverpod(keepAlive: true)
ResolveAgentContactUseCase resolveAgentContactUseCase(Ref ref) {
  return ResolveAgentContactUseCase(
    getContactByIdUseCase: ref.watch(getContactByIdUseCaseProvider),
    searchContactsUseCase: ref.watch(searchContactsUseCaseProvider),
  );
}

/// Resolves a spoken name hint against Drift FTS with Arabic retries.
@Riverpod(keepAlive: true)
ResolveContactHintUseCase resolveContactHintUseCase(Ref ref) {
  return ResolveContactHintUseCase(
    searchContactsUseCase: ref.watch(searchContactsUseCaseProvider),
  );
}

/// Lists name-match candidates for money-proposal disambiguation.
@Riverpod(keepAlive: true)
ListAgentContactCandidatesUseCase listAgentContactCandidatesUseCase(Ref ref) {
  return ListAgentContactCandidatesUseCase(
    resolveContactHintUseCase: ref.watch(resolveContactHintUseCaseProvider),
  );
}

/// Answers ask-the-books from Drift balances.
@Riverpod(keepAlive: true)
AnswerAskBooksUseCase answerAskBooksUseCase(Ref ref) {
  return AnswerAskBooksUseCase(
    balanceRepository: ref.watch(balanceRepositoryProvider),
    contactRepository: ref.watch(contactRepositoryProvider),
    resolveContactHintUseCase: ref.watch(resolveContactHintUseCaseProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
  );
}

/// Confirm-gate with money/contact writes + Day Journal.
@Riverpod(keepAlive: true)
CommitAgentProposalUseCase commitAgentProposalUseCase(Ref ref) {
  return CommitAgentProposalUseCase(
    confirmGate: ref.watch(agentConfirmGateProvider),
    agentTurnRepository: ref.watch(agentTurnRepositoryProvider),
    updateConfirmStateUseCase: ref.watch(
      updateAgentTurnConfirmStateUseCaseProvider,
    ),
    resolveAgentContactUseCase: ref.watch(resolveAgentContactUseCaseProvider),
    addTransactionUseCase: ref.watch(addTransactionUseCaseProvider),
    createContactUseCase: ref.watch(createContactUseCaseProvider),
    createLedgerUseCase: ref.watch(createLedgerUseCaseProvider),
    appendDayJournalEntryUseCase: ref.watch(
      appendDayJournalEntryUseCaseProvider,
    ),
    settingsRepository: ref.watch(settingsRepositoryProvider),
    getLedgersUseCase: ref.watch(getLedgersUseCaseProvider),
  );
}
