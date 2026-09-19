import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:shopping_list/apps/tasks/data/models/task_item.dart';

/// Local alerts for due and snoozed tasks.
///
/// SQLite is the source of truth. [rebuild] cancels everything and schedules
/// from the open items, so a killed process still matches the database after
/// the next launch (and after reboot, once the app is opened).
class TaskAlerts {
  TaskAlerts._();

  static final TaskAlerts instance = TaskAlerts._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  int? _pendingOpenTaskId;

  /// Set by [TaskAlertHost] so a tap can open Tasks on that card.
  void Function(int taskId)? onOpenTask;

  static const _channelId = 'tasks.due';
  static const _channelName = 'Tasks';

  Future<void> ensureReady() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } on Object {
      tz.setLocalLocation(tz.UTC);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (response) {
        _handlePayload(response.payload);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _handlePayload(launch!.notificationResponse?.payload);
    }
    _ready = true;
  }

  void flushPendingOpen() {
    final id = _pendingOpenTaskId;
    _pendingOpenTaskId = null;
    if (id != null) onOpenTask?.call(id);
  }

  void _handlePayload(String? payload) {
    if (payload == null || !payload.startsWith('task:')) return;
    final id = int.tryParse(payload.substring(5));
    if (id == null) return;
    if (onOpenTask != null) {
      onOpenTask!(id);
    } else {
      _pendingOpenTaskId = id;
    }
  }

  Future<bool> requestPermission() async {
    await ensureReady();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    await android.requestExactAlarmsPermission();
    return await android.requestNotificationsPermission() ?? false;
  }

  Future<void> rebuild(List<TaskItem> items) async {
    try {
      await ensureReady();
    } on Object {
      return;
    }
    try {
      await _plugin.cancelAll();
    } on Object {
      return;
    }
    final now = DateTime.now();
    for (final item in items) {
      final id = item.id;
      if (id == null) continue;
      final when = _fireAt(item, now);
      if (when == null || !when.isAfter(now)) continue;
      try {
        await _schedule(id, item.title, when);
      } on Object {
        // Exact-alarm or plugin failures must not break a save.
      }
    }
  }

  DateTime? _fireAt(TaskItem item, DateTime now) {
    final snooze = item.snoozedUntil;
    if (snooze != null && snooze.isAfter(now)) return snooze;
    final due = item.dueAt;
    if (due == null) return null;
    if (due.hour == 0 && due.minute == 0 && due.second == 0) {
      return DateTime(due.year, due.month, due.day, 9);
    }
    return due;
  }

  Future<void> _schedule(int id, String title, DateTime when) async {
    await _plugin.zonedSchedule(
      id,
      title,
      'A task is waiting.',
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Due and snoozed tasks',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'task:$id',
    );
  }
}
