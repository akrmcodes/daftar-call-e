// Explicit urgent/default notification configuration intentionally keeps the
// plugin's default values visible here, so suppress the noisy style-only lint.
// ignore_for_file: avoid_redundant_argument_values, prefer_const_constructors

import 'package:daftar/domain/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notification service backed by `flutter_local_notifications`.
class NotificationServiceImpl implements NotificationService {
  /// Creates a notification service wrapper.
  NotificationServiceImpl({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _defaultChannelId = 'standard_alerts_channel';
  static const String _defaultChannelName = 'Standard Alerts';
  static const String _urgentChannelId = 'urgent_alerts_channel';
  static const String _urgentChannelName = 'Urgent Alerts';
  static const String _channelDescription =
      'Important financial alerts and reminders';
  static final Int64List _urgentVibrationPattern = Int64List.fromList(
    <int>[0, 500, 200, 500, 200, 500],
  );

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized || kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_daftar'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      );

      await _plugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      const standardChannel = AndroidNotificationChannel(
        _defaultChannelId,
        _defaultChannelName,
        description: _channelDescription,
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: false,
      );

      final urgentChannel = AndroidNotificationChannel(
        _urgentChannelId,
        _urgentChannelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: _urgentVibrationPattern,
      );

      await androidPlugin?.createNotificationChannel(standardChannel);
      await androidPlugin?.createNotificationChannel(urgentChannel);

      _initialized = true;
    } on Object {
      // Notification startup must never block app launch.
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (kIsWeb) {
      return true;
    }

    await _ensureInitialized();

    var granted = true;

    try {
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImplementation != null) {
        final androidGranted = await androidImplementation
            .requestNotificationsPermission();
        granted = androidGranted ?? granted;
      }
    } on Object {
      granted = false;
    }

    try {
      final iosImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosImplementation != null) {
        final iosGranted = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        granted = iosGranted ?? granted;
      }
    } on Object {
      granted = false;
    }

    try {
      final macosImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macosImplementation != null) {
        final macosGranted = await macosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        granted = macosGranted ?? granted;
      }
    } on Object {
      granted = false;
    }

    return granted;
  }

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    bool isUrgent = false,
    String? payload,
  }) async {
    if (kIsWeb) {
      return;
    }

    await _ensureInitialized();

    if (!_initialized) {
      return;
    }

    try {
      final notificationDetails = isUrgent
          ? NotificationDetails(
              android: AndroidNotificationDetails(
                _urgentChannelId,
                _urgentChannelName,
                channelDescription: _channelDescription,
                importance: Importance.max,
                priority: Priority.high,
                enableVibration: true,
                vibrationPattern: _urgentVibrationPattern,
                playSound: true,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
                interruptionLevel: InterruptionLevel.timeSensitive,
              ),
              macOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
                interruptionLevel: InterruptionLevel.timeSensitive,
              ),
            )
          : NotificationDetails(
              android: AndroidNotificationDetails(
                _defaultChannelId,
                _defaultChannelName,
                channelDescription: _channelDescription,
                playSound: true,
                enableVibration: false,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
                interruptionLevel: InterruptionLevel.active,
              ),
              macOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
                interruptionLevel: InterruptionLevel.active,
              ),
            );

      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } on Object {
      // Notification delivery is best-effort only.
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  void _onNotificationResponse(NotificationResponse response) {}
}
