import 'package:daftar/application/collaboration/accept_worker_invite_use_case.dart';
import 'package:daftar/core/services/pending_worker_invite_store.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/deep_link_providers.dart';
import 'package:daftar/presentation/providers/sync_auth_bridge_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'collaboration_invite_providers.g.dart';

@Riverpod(keepAlive: true)
PendingWorkerInviteStore pendingWorkerInviteStore(Ref ref) {
  return PendingWorkerInviteStore();
}

@Riverpod(keepAlive: true)
AcceptWorkerInviteUseCase acceptWorkerInviteUseCase(Ref ref) {
  return AcceptWorkerInviteUseCase(
    authRepository: ref.watch(authRepositoryProvider),
    exchangeSyncTokenUseCase: ref.watch(exchangeSyncTokenUseCaseProvider),
    claimDeepLinkUseCase: ref.watch(claimDeepLinkUseCaseProvider),
    pendingInviteStore: ref.watch(pendingWorkerInviteStoreProvider),
  );
}
