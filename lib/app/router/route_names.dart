abstract final class RouteNames {
  static const home = 'home';
  static const settings = 'settings';
  static const ledgerDetail = 'ledgerDetail';
  static const contactDetail = 'contactDetail';
  static const importCsv = 'importCsv';
  static const backup = 'backup';
  static const activation = 'activation';
  static const security = 'security';
  static const merchantBranding = 'merchantBranding';
  static const accountManagement = 'accountManagement';
  static const archiveVault = 'archiveVault';
  /// Debug-only diagnostic route — not registered in release/profile builds.
  static const preflightSmokeTest = 'preflightSmokeTest';
  static const onboarding = 'onboarding';
  static const syncReport = 'syncReport';
  static const memberManagement = 'memberManagement';
  static const inviteCeremony = 'inviteCeremony';
  static const inviteAccept = 'inviteAccept';
  static const joinWorkspace = 'joinWorkspace';
  static const closingAgent = 'closingAgent';

  static const homePath = '/';
  static const settingsPath = '/settings';
  static const importCsvPath = '/settings/import-csv';
  static const backupPath = '/settings/backup';
  static const activationPath = '/settings/premium';
  static const securityPath = '/settings/security';
  static const merchantBrandingPath = '/settings/merchant-branding';
  static const accountManagementPath = '/settings/account';
  static const archiveVaultPath = '/archive-vault';
  /// Debug-only — `/settings/preflight-smoke-test` is not registered in release/profile.
  static const preflightSmokeTestPath = '/settings/preflight-smoke-test';
  static const onboardingPath = '/onboarding';
  static const syncReportPath = '/settings/sync-report';
  static const memberManagementPath = '/settings/members';
  static const inviteCeremonyPath = '/invite/ceremony';
  static const inviteAcceptPath = '/invite/accept';
  static const joinWorkspacePath = '/settings/join-workspace';
  static const closingAgentPath = '/closing-agent';
  static const ledgerDetailPath = '/ledgers/:ledgerId';
  static const contactDetailPath = '/contacts/:contactId';

  static const ledgerIdParam = 'ledgerId';
  static const contactIdParam = 'contactId';
}
