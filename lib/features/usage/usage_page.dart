import 'package:flutter/material.dart';

import 'package:emotion_app/core/theme/app_colors.dart';
import 'package:emotion_app/data/api/api_helpers.dart';
import 'package:emotion_app/data/api/backend_api.dart';
import 'package:emotion_app/data/device/device_usage_service.dart';
import 'package:emotion_app/shared/widgets/app_widgets.dart';

enum _UsagePeriod {
  today('오늘', 1),
  week('1주', 7),
  month('1달', 30);

  const _UsagePeriod(this.label, this.days);

  final String label;
  final int days;
}

class UsagePage extends StatefulWidget {
  const UsagePage({super.key});

  @override
  State<UsagePage> createState() => _UsagePageState();
}

class _UsagePageState extends State<UsagePage> {
  final api = BackendApi();
  final deviceUsage = DeviceUsageService();

  bool loading = true;
  bool syncing = false;
  bool hasUsagePermission = false;
  bool hasAccessibilityPermission = false;
  bool alertShown = false;
  String? error;
  int totalMinutes = 0;
  _UsagePeriod period = _UsagePeriod.today;
  List<Map<String, dynamic>> logs = [];
  List<DeviceUsageApp> deviceLogs = [];
  List<_DailyPoint> dailyPoints = [];
  int _usageLoadVersion = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final usageLoadVersion = ++_usageLoadVersion;
    final requestedPeriod = period;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final range = _rangeFor(requestedPeriod);
      var serverLogs = <Map<String, dynamic>>[];

      hasUsagePermission = await deviceUsage.hasPermission();
      hasAccessibilityPermission = await deviceUsage
          .hasAccessibilityPermission();

      if (hasUsagePermission) {
        final overview = await deviceUsage.getUsageOverviewRange(
          range.start,
          range.end,
        );
        deviceLogs = overview.apps;
        dailyPoints = _fillDailyPoints(requestedPeriod, overview.dailyTotals);
      } else {
        deviceLogs = [];
        dailyPoints = _fillDailyPoints(requestedPeriod, const []);
      }

      if (requestedPeriod == _UsagePeriod.today) {
        final response = await _ignore(
          api.getUsageSummary(date: _todayKstKey()),
        );
        final data = asMap(response?['data']);
        serverLogs = asMapList(data?['usage_logs']);
      }

      if (usageLoadVersion != _usageLoadVersion || requestedPeriod != period) return;
      if (!mounted) return;
      setState(() {
        logs = deviceLogs.isNotEmpty
            ? deviceLogs
                  .map(
                    (item) => {
                      'app_name': item.appName,
                      'duration_minutes': item.durationMinutes,
                    },
                  )
                  .toList()
            : serverLogs;

        final deviceTotal = dailyPoints.fold<int>(
          0,
          (sum, point) => sum + point.minutes,
        );
        totalMinutes = deviceTotal > 0
            ? deviceTotal
            : logs.fold<int>(
                0,
                (sum, row) => sum + asInt(row['duration_minutes']),
              );

        if (requestedPeriod == _UsagePeriod.today &&
            dailyPoints.every((point) => point.minutes == 0) &&
            totalMinutes > 0) {
          dailyPoints = [_DailyPoint(label: '오늘', minutes: totalMinutes)];
        }
      });
      _showHighUsageAlertIfNeeded();
    } catch (e) {
      if (usageLoadVersion != _usageLoadVersion || requestedPeriod != period) return;
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted && usageLoadVersion == _usageLoadVersion && requestedPeriod == period) {
        setState(() => loading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _ignore(
    Future<Map<String, dynamic>> future,
  ) async {
    try {
      return await future;
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncDeviceUsage() async {
    if (!hasUsagePermission) {
      await deviceUsage.openSettings();
      return;
    }

    setState(() => syncing = true);
    try {
      for (final item in deviceLogs.take(20)) {
        await api.logUsage(
          appName: item.appName,
          durationMinutes: item.durationMinutes,
          loggedAt: DateTime.now(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('현재 사용시간을 서버에 저장했어요.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  Future<void> _openUsageSettings() async {
    await deviceUsage.openSettings();
  }

  Future<void> _openAccessibilitySettings() async {
    await deviceUsage.openAccessibilitySettings();
  }

  void _changePeriod(_UsagePeriod next) {
    if (period == next) return;
    setState(() {
      period = next;
      alertShown = false;
    });
    _load();
  }

  void _showHighUsageAlertIfNeeded() {
    if (!mounted ||
        alertShown ||
        period != _UsagePeriod.today ||
        totalMinutes < 300) {
      return;
    }
    alertShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('사용시간 알림'),
          content: Text(
            '오늘 스마트폰 사용시간이 ${formatMinutes(totalMinutes)}입니다. 잠깐 쉬어가도 좋아요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    });
  }

  ({DateTime start, DateTime end}) _rangeFor(_UsagePeriod value) {
    final nowUtc = DateTime.now().toUtc();
    final nowKst = DeviceUsageService.nowKst();
    final startKst = DateTime(
      nowKst.year,
      nowKst.month,
      nowKst.day,
    ).subtract(Duration(days: value.days - 1));
    return (start: DeviceUsageService.kstMidnightAsUtc(startKst), end: nowUtc);
  }

  String _todayKstKey() =>
      DeviceUsageService.dateKey(DeviceUsageService.nowKst());

  List<_DailyPoint> _fillDailyPoints(
    _UsagePeriod value,
    List<DailyUsageTotal> totals,
  ) {
    final byDate = {for (final item in totals) item.date: item.durationMinutes};
    final nowKst = DeviceUsageService.nowKst();
    final firstDay = DateTime(
      nowKst.year,
      nowKst.month,
      nowKst.day,
    ).subtract(Duration(days: value.days - 1));
    return List.generate(value.days, (index) {
      final day = firstDay.add(Duration(days: index));
      return _DailyPoint(
        label: value == _UsagePeriod.today ? '오늘' : '${day.month}/${day.day}',
        minutes: byDate[DeviceUsageService.dateKey(day)] ?? 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chartValues = dailyPoints
        .map((point) => point.minutes <= 0 ? 1.0 : point.minutes.toDouble())
        .toList();

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const AppHeader(title: '사용시간'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  children: [
                    _PeriodTabs(selected: period, onChanged: _changePeriod),
                    if (error != null)
                      _ErrorCard(message: error!, onRetry: _load),
                    if (!hasUsagePermission || !hasAccessibilityPermission)
                      _PermissionCard(
                        hasUsagePermission: hasUsagePermission,
                        hasAccessibilityPermission: hasAccessibilityPermission,
                        onOpenUsageSettings: _openUsageSettings,
                        onOpenAccessibilitySettings: _openAccessibilitySettings,
                      ),
                    _UsageSummaryCard(
                      period: period,
                      totalMinutes: totalMinutes,
                      loading: loading,
                      chartValues: chartValues,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: YellowButton(
                        label: hasUsagePermission
                            ? (syncing ? '저장 중...' : '현재 사용시간 서버에 저장')
                            : '사용정보 접근 권한 열기',
                        onPressed: syncing ? null : _syncDeviceUsage,
                      ),
                    ),
                    _UsageListCard(logs: logs),
                    _DailyUsageCard(period: period, points: dailyPoints),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyPoint {
  const _DailyPoint({required this.label, required this.minutes});

  final String label;
  final int minutes;
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.hasUsagePermission,
    required this.hasAccessibilityPermission,
    required this.onOpenUsageSettings,
    required this.onOpenAccessibilitySettings,
  });

  final bool hasUsagePermission;
  final bool hasAccessibilityPermission;
  final VoidCallback onOpenUsageSettings;
  final VoidCallback onOpenAccessibilitySettings;

  @override
  Widget build(BuildContext context) {
    return DesignCard(
      color: const Color(0xfffffbec),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '권한이 필요해요',
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '사용시간 집계는 사용정보 접근 권한이 필요하고, 현재 앱 감지 알림은 접근성 권한을 켜야 정확해집니다.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (!hasUsagePermission)
            YellowButton(
              label: '사용정보 접근 권한 열기',
              onPressed: onOpenUsageSettings,
            ),
          if (!hasUsagePermission && !hasAccessibilityPermission)
            const SizedBox(height: 8),
          if (!hasAccessibilityPermission)
            YellowButton(
              label: '접근성 권한 열기',
              onPressed: onOpenAccessibilitySettings,
              filled: false,
            ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DesignCard(
      color: const Color(0xfffff4f2),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selected, required this.onChanged});

  final _UsagePeriod selected;
  final ValueChanged<_UsagePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xffd9cdb9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: _UsagePeriod.values
            .map(
              (period) => _PeriodTab(
                label: period.label,
                selected: selected == period,
                onTap: () => onChanged(period),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  const _PeriodTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.amber : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.mutedText,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _UsageSummaryCard extends StatelessWidget {
  const _UsageSummaryCard({
    required this.period,
    required this.totalMinutes,
    required this.loading,
    required this.chartValues,
  });

  final _UsagePeriod period;
  final int totalMinutes;
  final bool loading;
  final List<double> chartValues;

  @override
  Widget build(BuildContext context) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final title = switch (period) {
      _UsagePeriod.today => '오늘 총 사용 시간',
      _UsagePeriod.week => '최근 7일 총 사용 시간',
      _UsagePeriod.month => '최근 30일 총 사용 시간',
    };

    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$hours시간 ',
                  style: const TextStyle(color: AppColors.navy),
                ),
                TextSpan(
                  text: '$minutes분',
                  style: const TextStyle(color: AppColors.amber),
                ),
              ],
            ),
            style: const TextStyle(
              fontSize: 27,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            '기기 사용정보를 기준으로 앱별 사용시간을 집계합니다.',
            style: TextStyle(fontSize: 12, color: AppColors.mutedText),
          ),
          const SizedBox(height: 18),
          MiniBarChart(values: chartValues),
        ],
      ),
    );
  }
}

class _UsageListCard extends StatelessWidget {
  const _UsageListCard({required this.logs});

  final List<Map<String, dynamic>> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const DesignCard(
        child: Text(
          '표시할 앱 사용시간 데이터가 아직 없어요.',
          style: TextStyle(color: AppColors.mutedText),
        ),
      );
    }

    final maxMinutes = logs
        .map((row) => asInt(row['duration_minutes']))
        .fold<int>(1, (a, b) => a > b ? a : b);

    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  '앱별 사용 시간',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '기기 데이터',
                style: TextStyle(
                  color: AppColors.blue,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...logs.take(12).map((row) {
            final name = row['app_name']?.toString() ?? '알 수 없는 앱';
            final minutes = asInt(row['duration_minutes']);
            return UsageRow(
              initials: _initials(name),
              name: name,
              time: formatMinutes(minutes),
              color: _colorFor(name),
              progress: (minutes / maxMinutes).clamp(0.05, 1.0),
            );
          }),
        ],
      ),
    );
  }

  String _initials(String name) {
    final letters = name.replaceAll(' ', '');
    if (letters.isEmpty) return '--';
    if (letters.length <= 2) return letters.toUpperCase();
    return letters.substring(0, 2).toUpperCase();
  }

  Color _colorFor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('youtube')) return AppColors.red;
    if (lower.contains('instagram')) return const Color(0xffdf2760);
    if (lower.contains('kakao')) return AppColors.brown;
    if (lower.contains('tiktok')) return Colors.black;
    if (lower.contains('naver')) return AppColors.green;
    return AppColors.blue;
  }
}

class _DailyUsageCard extends StatelessWidget {
  const _DailyUsageCard({required this.period, required this.points});

  final _UsagePeriod period;
  final List<_DailyPoint> points;

  @override
  Widget build(BuildContext context) {
    final visiblePoints = period == _UsagePeriod.month
        ? [
            for (var i = 0; i < points.length; i++)
              if (i % 5 == 0 || i == points.length - 1) points[i],
          ]
        : points;

    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            period == _UsagePeriod.today ? '오늘 사용시간' : '날짜별 총 사용시간',
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 18),
          MiniBarChart(
            values: points
                .map(
                  (point) =>
                      point.minutes <= 0 ? 1.0 : point.minutes.toDouble(),
                )
                .toList(),
            compact: true,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: visiblePoints
                .map(
                  (point) => Text(
                    point.label,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 10,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
