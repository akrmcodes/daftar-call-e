import 'dart:async';

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

class OnboardingGateNotifier extends ChangeNotifier {
  OnboardingGateNotifier(Stream<AppSettings> settingsStream) {
    _subscription = settingsStream.listen(_onSettings);
  }

  late final StreamSubscription<AppSettings> _subscription;
  bool _hasSeenOnboarding = false;
  bool _isLoaded = false;

  bool get hasSeenOnboarding => _hasSeenOnboarding;

  bool get isLoaded => _isLoaded;

  void _onSettings(AppSettings settings) {
    _hasSeenOnboarding = settings.hasSeenOnboarding;
    _isLoaded = true;
    notifyListeners();
  }

  String? redirect(GoRouterState state) {
    if (!_isLoaded) {
      return null;
    }
    final location = state.matchedLocation;
    final isInvitePath = location == RouteNames.inviteCeremonyPath ||
        location == RouteNames.inviteAcceptPath;
    if (isInvitePath) {
      return null;
    }
    if (!_hasSeenOnboarding && location != RouteNames.onboardingPath) {
      return RouteNames.onboardingPath;
    }
    if (_hasSeenOnboarding && location == RouteNames.onboardingPath) {
      return RouteNames.homePath;
    }
    return null;
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
