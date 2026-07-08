import 'package:flutter/material.dart';

import 'package:emotion_app/core/theme/app_colors.dart';
import 'package:emotion_app/data/api/api_helpers.dart';
import 'package:emotion_app/data/api/backend_api.dart';
import 'package:emotion_app/data/device/device_usage_service.dart';
import 'package:emotion_app/shared/widgets/app_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final api = BackendApi();
  final deviceUsage = DeviceUsageService();
  bool loading = true;
  bool hasUsagePermission = false;
  String? error;
  int totalMinutes = 0;
  List<Map<String, dynamic>> usageLogs = [];
  Map<String, dynamic>? cesdResult;
  String notice = '잠깐 쉬어가며 내 마음을 확인해보세요.';
  String? noticeAuthor;
  bool showCesdCard = true;
  bool showChatbotCard = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      var serverLogs = <Map<String, dynamic>>[];
      var serverTotal = 0;

      final usage = await _ignore(api.getUsageSummary());
      final usageData = asMap(usage?['data']);
      serverTotal = asInt(usageData?['total_usage_minutes']);
      serverLogs = asMapList(usageData?['usage_logs']);

      hasUsagePermission = await deviceUsage.hasPermission();
      if (hasUsagePermission) {
        final range = DeviceUsageService.todayKstRange();
        final apps = await deviceUsage.getUsageRange(range.start, range.end);
        final daily = await deviceUsage.getDailyUsageRange(
          range.start,
          range.end,
        );
        final todayKey = DeviceUsageService.dateKey(
          DeviceUsageService.nowKst(),
        );
        final todayTotal = daily
            .where((item) => item.date == todayKey)
            .fold<int>(0, (sum, item) => sum + item.durationMinutes);
        if (apps.isNotEmpty || todayTotal > 0) {
          serverLogs = apps
              .map(
                (item) => {
                  'app_name': item.appName,
                  'duration_minutes': item.durationMinutes,
                },
              )
              .toList();
          serverTotal = todayTotal > 0
              ? todayTotal
              : apps.fold<int>(0, (sum, item) => sum + item.durationMinutes);
        }
      }

      final result = await _ignore(api.getCesdResult());
      final noticeResult = await _ignore(api.getRandomNotice());
      final status = await _ignore(api.getCardStatus());

      if (!mounted) return;
      setState(() {
        totalMinutes = serverTotal;
        usageLogs = serverLogs;
        cesdResult = asMap(result?['data']);
        final noticeData = asMap(noticeResult?['data']);
        notice = noticeData?['message']?.toString() ?? notice;
        noticeAuthor = noticeData?['author']?.toString();
        showCesdCard = asBool(status?['showCESDCard'], true);
        showChatbotCard = asBool(status?['showChatbotCard'], true);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
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

  Future<void> _dismissChatbotCard() async {
    try {
      await api.dismissChatbotCard();
      if (mounted) setState(() => showChatbotCard = false);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppHeader(title: ''),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '오늘 요약',
                              style: TextStyle(
                                color: AppColors.navy,
                                fontSize: 14,
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
                    ),
                    if (error != null)
                      _ErrorBanner(message: error!, onRetry: _load),
                    if (!hasUsagePermission)
                      _PermissionHint(onOpenSettings: deviceUsage.openSettings),
                    _TodaySummaryCard(
                      totalMinutes: totalMinutes,
                      fromDevice: hasUsagePermission,
                    ),
                    _AppUsageCard(logs: usageLogs),
                    if (showCesdCard) _DiagnosisCard(result: cesdResult),
                    if (showChatbotCard)
                      _ChatCtaCard(onDismiss: _dismissChatbotCard),
                    _MindSentenceCard(message: notice, author: noticeAuthor),
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

class _PermissionHint extends StatelessWidget {
  const _PermissionHint({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return DesignCard(
      color: const Color(0xfffffbec),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '홈에서 실제 사용시간을 보려면 사용정보 접근 권한이 필요해요.',
              style: TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
          ),
          TextButton(onPressed: onOpenSettings, child: const Text('설정 열기')),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

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
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({
    required this.totalMinutes,
    required this.fromDevice,
  });

  final int totalMinutes;
  final bool fromDevice;

  @override
  Widget build(BuildContext context) {
    const goal = 330;
    final progress = totalMinutes == 0
        ? 0.0
        : (totalMinutes / goal).clamp(0.0, 1.0);
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return DesignCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '오늘의 스마트폰 사용 시간',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
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
                const SizedBox(height: 9),
                Text(
                  totalMinutes == 0
                      ? '오늘 사용시간 데이터가 아직 없어요.'
                      : fromDevice
                      ? '휴대폰 사용정보에서 바로 불러왔어요.'
                      : '백엔드 저장값에서 불러왔어요.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.amber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: AppColors.blueSoft,
                  valueColor: const AlwaysStoppedAnimation(AppColors.amber),
                ),
                Center(
                  child: Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppUsageCard extends StatelessWidget {
  const _AppUsageCard({required this.logs});

  final List<Map<String, dynamic>> logs;

  @override
  Widget build(BuildContext context) {
    final rows = logs.isEmpty
        ? const [
            {'app_name': '데이터 없음', 'duration_minutes': 0},
          ]
        : logs;
    final maxMinutes = rows
        .map((row) => asInt(row['duration_minutes']))
        .fold<int>(1, (a, b) => a > b ? a : b);

    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '앱별 사용 시간',
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ...rows.take(3).map((row) {
            final name = row['app_name']?.toString() ?? '앱';
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
    return AppColors.green;
  }
}

class _DiagnosisCard extends StatelessWidget {
  const _DiagnosisCard({required this.result});

  final Map<String, dynamic>? result;

  @override
  Widget build(BuildContext context) {
    final score = result == null ? '-' : asInt(result!['score']).toString();
    final level = _levelLabel(result?['level']?.toString());
    return DesignCard(
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.blueSoft,
            child: Icon(
              Icons.assignment_outlined,
              color: AppColors.navy,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CES-D 자가진단 결과',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '점수 $score/60 - $level',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _levelLabel(String? level) {
    switch (level) {
      case 'normal':
        return '정상 범위';
      case 'mild_depression':
        return '경미한 우울 상태 가능성';
      case 'severe_depression':
        return '높은 우울 상태 가능성';
      case null:
      case '':
        return '결과 없음';
      default:
        return level;
    }
  }
}

class _ChatCtaCard extends StatelessWidget {
  const _ChatCtaCard({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return DesignCard(
      color: AppColors.navyCard,
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xff3d6fa5),
            child: Icon(
              Icons.smart_toy_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '마음이 지칠 때 AI 챗봇이 함께할게요',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: onDismiss,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('7일 동안 숨기기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MindSentenceCard extends StatelessWidget {
  const _MindSentenceCard({required this.message, this.author});

  final String message;
  final String? author;

  @override
  Widget build(BuildContext context) {
    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '마음 문구',
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (author != null) ...[
            const SizedBox(height: 6),
            Text(
              '- $author',
              style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
