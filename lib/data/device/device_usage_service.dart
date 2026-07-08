import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceUsageApp {
  const DeviceUsageApp({
    required this.packageName,
    required this.appName,
    required this.durationMinutes,
  });

  final String packageName;
  final String appName;
  final int durationMinutes;
}

class CurrentForegroundUsage {
  const CurrentForegroundUsage({
    required this.packageName,
    required this.appName,
    required this.durationMinutes,
    required this.currentSessionMinutes,
  });

  final String packageName;
  final String appName;
  final int durationMinutes;
  final int currentSessionMinutes;
}

class DailyUsageTotal {
  const DailyUsageTotal({required this.date, required this.durationMinutes});

  final String date;
  final int durationMinutes;
}

class UsageOverview {
  const UsageOverview({required this.apps, required this.dailyTotals});

  final List<DeviceUsageApp> apps;
  final List<DailyUsageTotal> dailyTotals;
}

class DeviceUsageService {
  static const _channel = MethodChannel('mind_balance/usage_stats');
  static const kstOffset = Duration(hours: 9);

  Future<bool> hasPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    return await _channel.invokeMethod<bool>('hasPermission') ?? false;
  }

  Future<void> openSettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('openSettings');
  }

  Future<bool> hasAccessibilityPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    return await _channel.invokeMethod<bool>('hasAccessibilityPermission') ??
        false;
  }

  Future<void> openAccessibilitySettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('openAccessibilitySettings');
  }

  Future<void> startUsageAlertService() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('startUsageAlertService');
  }

  Future<List<DeviceUsageApp>> getTodayUsage() async {
    final range = todayKstRange();
    return getUsageRange(range.start, range.end);
  }

  Future<List<DeviceUsageApp>> getUsageRange(
    DateTime start,
    DateTime end,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.android) return const [];
    final result =
        await _channel.invokeMethod<List<dynamic>>('getUsageRange', {
          'startMillis': start.millisecondsSinceEpoch,
          'endMillis': end.millisecondsSinceEpoch,
        }) ??
        const [];
    return result
        .map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return DeviceUsageApp(
            packageName: map['packageName']?.toString() ?? '',
            appName: map['appName']?.toString() ?? '알 수 없는 앱',
            durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
          );
        })
        .where((item) => item.durationMinutes > 0)
        .toList();
  }

  Future<UsageOverview> getUsageOverviewRange(
    DateTime start,
    DateTime end,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const UsageOverview(apps: [], dailyTotals: []);
    }
    final result =
        await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'getUsageOverviewRange',
          {
            'startMillis': start.millisecondsSinceEpoch,
            'endMillis': end.millisecondsSinceEpoch,
          },
        ) ??
        const {};
    final usage = (result['usage'] as List<dynamic>? ?? const [])
        .map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return DeviceUsageApp(
            packageName: map['packageName']?.toString() ?? '',
            appName: map['appName']?.toString() ?? '알 수 없는 앱',
            durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
          );
        })
        .where((item) => item.durationMinutes > 0)
        .toList();
    final daily = (result['daily'] as List<dynamic>? ?? const [])
        .map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return DailyUsageTotal(
            date: map['date']?.toString() ?? '',
            durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
          );
        })
        .where((item) => item.date.isNotEmpty)
        .toList();

    return UsageOverview(apps: usage, dailyTotals: daily);
  }

  Future<CurrentForegroundUsage?> getCurrentForegroundUsage() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>?>(
      'getCurrentForegroundUsage',
    );
    if (result == null || result.isEmpty) return null;

    final map = Map<String, dynamic>.from(result);
    final packageName = map['packageName']?.toString() ?? '';
    if (packageName.isEmpty) return null;

    return CurrentForegroundUsage(
      packageName: packageName,
      appName: map['appName']?.toString() ?? '알 수 없는 앱',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
      currentSessionMinutes:
          (map['currentSessionMinutes'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<DailyUsageTotal>> getDailyUsageRange(
    DateTime start,
    DateTime end,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.android) return const [];
    final result =
        await _channel.invokeMethod<List<dynamic>>('getDailyUsageRange', {
          'startMillis': start.millisecondsSinceEpoch,
          'endMillis': end.millisecondsSinceEpoch,
        }) ??
        const [];
    return result
        .map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return DailyUsageTotal(
            date: map['date']?.toString() ?? '',
            durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
          );
        })
        .where((item) => item.date.isNotEmpty)
        .toList();
  }

  static DateTime nowKst() => DateTime.now().toUtc().add(kstOffset);

  static DateTime kstMidnightAsUtc(DateTime kstDate) {
    return DateTime.utc(
      kstDate.year,
      kstDate.month,
      kstDate.day,
    ).subtract(kstOffset);
  }

  static ({DateTime start, DateTime end}) todayKstRange() {
    final nowUtc = DateTime.now().toUtc();
    final nowKst = nowUtc.add(kstOffset);
    return (start: kstMidnightAsUtc(nowKst), end: nowUtc);
  }

  static String dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
