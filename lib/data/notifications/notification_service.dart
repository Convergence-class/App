import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:emotion_app/data/device/device_usage_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _quoteNotificationId = 2400;
  static const _usageNotificationBaseId = 3500;
  static const _quoteChannelId = 'mind_balance_quotes';
  static const _usageChannelId = 'mind_balance_usage';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final DeviceUsageService _deviceUsage = DeviceUsageService();
  Timer? _quoteTimer;
  Timer? _usageTimer;
  int _quoteIndex = 0;
  bool _initialized = false;

  static const quotes = [
    '스마트폰은 편리함을 주는 도구이지만, 과도하게 붙잡으면 우리 삶을 오히려 좁히는 족쇄가 될 수 있다.',
    '스마트폰은 창문처럼 세상을 보여주지만, 창문만 바라보다 보면 정작 내 삶의 풍경을 놓치게 된다.',
    '스마트폰은 때로는 등불이 되지만, 과하게 쓰면 눈부심 때문에 길을 잃게 한다.',
    '우리는 도구를 만든다. 그리고 그 도구가 결국 우리를 만든다. - 마셜 맥루언',
    '현대인은 기계를 더 편리하게 만들지만, 그만큼 스스로는 불편해지고 있다. - 알베르트 아인슈타인',
    '기술은 훌륭한 종이 될 수 있지만, 끔찍한 주인이 될 수도 있다. - 크리스티안 루이스 랑게',
    '어떤 쾌락에 대한 생각이 상상력을 자극할 때 특히 경계해야 합니다. - 스토아 학파 조언',
    '기술이 인간의 소통을 넘어서는 순간, 우리는 기계의 노예가 된다.',
    '고개를 들면 더 넓은 세상이 보인다.',
    '생각하는 대로 살지 않으면 사는 대로 생각하게 된다. - 폴 발레리',
    '지식의 발달은 인간을 행복하게 하지만, 기계에 대한 맹신은 인류의 가장 큰 재앙이 될 것이다. - 알베르트 아인슈타인',
  ];

  Future<void> initialize() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> start() async {
    await initialize();
    await _scheduleRepeatingQuoteForTest();
    _startQuoteTimerForTest();
    _startUsageMonitor();
    await _deviceUsage.startUsageAlertService();
  }

  Future<void> checkUsageMilestonesNow() async {
    await initialize();
    await _checkUsageMilestones();
  }

  Future<void> _scheduleRepeatingQuoteForTest() async {
    await _plugin.cancel(id: _quoteNotificationId);
    await _plugin.periodicallyShow(
      id: _quoteNotificationId,
      title: '잠시 쉬어가기',
      body: quotes.first,
      repeatInterval: RepeatInterval.everyMinute,
      notificationDetails: _quoteDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  void _startQuoteTimerForTest() {
    _quoteTimer?.cancel();
    _quoteTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      await _showNextQuote();
    });
  }

  void _startUsageMonitor() {
    _usageTimer?.cancel();
    _usageTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      await _checkUsageMilestones();
    });
    unawaited(_checkUsageMilestones());
  }

  Future<void> _showNextQuote() async {
    final quote = quotes[_quoteIndex % quotes.length];
    _quoteIndex += 1;
    await _plugin.show(
      id: _quoteNotificationId,
      title: '잠시 쉬어가기',
      body: quote,
      notificationDetails: _quoteDetails(),
    );
  }

  Future<void> _checkUsageMilestones() async {
    final hasPermission = await _deviceUsage.hasPermission();
    if (!hasPermission) return;

    final usage = await _deviceUsage.getCurrentForegroundUsage();
    if (usage == null) return;

    final usedHours = usage.durationMinutes ~/ 60;
    if (usedHours <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    final today = DeviceUsageService.dateKey(DeviceUsageService.nowKst());
    final key = 'usage_milestone.$today.${usage.packageName}';
    final lastNotifiedHour = prefs.getInt(key) ?? 0;
    if (usedHours <= lastNotifiedHour) return;

    await prefs.setInt(key, usedHours);
    await _plugin.show(
      id: _usageNotificationBaseId + usage.packageName.hashCode.abs() % 1000,
      title: '앱 사용시간 알림',
      body: '${usage.appName} 앱을 오늘 $usedHours시간 사용하고 있어요.',
      notificationDetails: _usageDetails(),
    );
  }

  NotificationDetails _quoteDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _quoteChannelId,
        '명언 알림',
        channelDescription: '스마트폰 사용 중 쉬어가기 명언을 보여줍니다.',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
  }

  NotificationDetails _usageDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _usageChannelId,
        '앱 사용시간 알림',
        channelDescription: '현재 사용 중인 앱의 사용시간 알림을 보여줍니다.',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
  }
}
