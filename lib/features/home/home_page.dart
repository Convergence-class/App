import 'package:flutter/material.dart';

import 'package:emotion_app/core/theme/app_colors.dart';
import 'package:emotion_app/data/api/api_helpers.dart';
import 'package:emotion_app/data/api/backend_api.dart';
import 'package:emotion_app/shared/widgets/app_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final api = BackendApi();
  bool loading = true;
  String? error;
  int totalMinutes = 0;
  List<Map<String, dynamic>> usageLogs = [];
  Map<String, dynamic>? cesdResult;
  String notice = 'Take a short break and come back to yourself.';
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
      final usage = await api.getUsageSummary();
      final usageData = asMap(usage['data']);
      final result = await _ignore(api.getCesdResult());
      final noticeResult = await _ignore(api.getRandomNotice());
      final status = await _ignore(api.getCardStatus());

      if (!mounted) return;
      setState(() {
        totalMinutes = asInt(usageData?['total_usage_minutes']);
        usageLogs = asMapList(usageData?['usage_logs']);
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
                              'Today summary',
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
                    _TodaySummaryCard(totalMinutes: totalMinutes),
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
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({required this.totalMinutes});

  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    final goal = 330;
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
                  'Phone usage today',
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
                        text: '${hours}h ',
                        style: const TextStyle(color: AppColors.navy),
                      ),
                      TextSpan(
                        text: '${minutes}m',
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
                      ? 'No server data yet.'
                      : 'Loaded from backend.',
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
            {'app_name': 'Instagram', 'duration_minutes': 88},
            {'app_name': 'YouTube', 'duration_minutes': 62},
            {'app_name': 'KakaoTalk', 'duration_minutes': 42},
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
            'App usage',
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ...rows.take(3).map((row) {
            final name = row['app_name']?.toString() ?? 'App';
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
    final level = result?['level']?.toString() ?? 'No result yet';
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
                  'CES-D result',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Score $score/60 - $level',
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
                  'Chatbot support is available',
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
                  child: const Text('Hide for 7 days'),
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
            'Notice',
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
