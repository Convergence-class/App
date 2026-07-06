import 'package:flutter/material.dart';

import 'package:emotion_app/core/theme/app_colors.dart';
import 'package:emotion_app/data/api/api_helpers.dart';
import 'package:emotion_app/data/api/backend_api.dart';
import 'package:emotion_app/shared/widgets/app_widgets.dart';

class UsagePage extends StatefulWidget {
  const UsagePage({super.key});

  @override
  State<UsagePage> createState() => _UsagePageState();
}

class _UsagePageState extends State<UsagePage> {
  final api = BackendApi();
  bool loading = true;
  bool saving = false;
  String? error;
  int totalMinutes = 0;
  List<Map<String, dynamic>> logs = [];

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
      final response = await api.getUsageSummary(date: _today());
      final data = asMap(response['data']);
      if (!mounted) return;
      setState(() {
        totalMinutes = asInt(data?['total_usage_minutes']);
        logs = asMapList(data?['usage_logs']);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _saveSample() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await api.logUsage(
        appName: 'YouTube',
        durationMinutes: 15,
        loggedAt: DateTime.now(),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const AppHeader(title: 'Usage'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  children: [
                    const _PeriodTabs(),
                    if (error != null)
                      _ErrorCard(message: error!, onRetry: _load),
                    _UsageSummaryCard(
                      totalMinutes: totalMinutes,
                      loading: loading,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: YellowButton(
                        label: saving
                            ? 'Saving...'
                            : 'Save sample 15 min usage',
                        onPressed: saving ? null : _saveSample,
                      ),
                    ),
                    _UsageListCard(logs: logs),
                    _WeeklyCard(values: _weeklyValues()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<double> _weeklyValues() {
    final today = totalMinutes == 0 ? 4.0 : totalMinutes / 15;
    return [8, 10, 13, 16, 13, 15, today.clamp(1, 20).toDouble()];
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
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xffd9cdb9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          _PeriodTab(label: 'Today', selected: true),
          _PeriodTab(label: 'Week'),
          _PeriodTab(label: 'Month'),
        ],
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  const _PeriodTab({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
    );
  }
}

class _UsageSummaryCard extends StatelessWidget {
  const _UsageSummaryCard({required this.totalMinutes, required this.loading});

  final int totalMinutes;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total usage today',
                  style: TextStyle(
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
          const SizedBox(height: 7),
          Text(
            totalMinutes == 0
                ? 'No usage data saved yet.'
                : 'Loaded from backend.',
            style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
          ),
          const SizedBox(height: 18),
          MiniBarChart(values: _chartValues(totalMinutes)),
        ],
      ),
    );
  }

  List<double> _chartValues(int total) {
    final last = total == 0 ? 3.0 : (total / 12).clamp(3, 22).toDouble();
    return [
      1,
      2,
      3,
      9,
      14,
      19,
      10,
      7,
      5,
      8,
      4,
      9,
      7,
      6,
      last,
      last + 2,
      last - 1,
      3,
    ];
  }
}

class _UsageListCard extends StatelessWidget {
  const _UsageListCard({required this.logs});

  final List<Map<String, dynamic>> logs;

  @override
  Widget build(BuildContext context) {
    final rows = logs.isEmpty
        ? const [
            {'app_name': 'Instagram', 'duration_minutes': 88},
            {'app_name': 'YouTube', 'duration_minutes': 62},
            {'app_name': 'KakaoTalk', 'duration_minutes': 42},
            {'app_name': 'Naver', 'duration_minutes': 28},
            {'app_name': 'TikTok', 'duration_minutes': 26},
          ]
        : logs;
    final maxMinutes = rows
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
                  'App usage',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                'Backend data',
                style: TextStyle(
                  color: AppColors.blue,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.take(5).map((row) {
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
          const Center(
            child: Text(
              'Example data is shown when server logs are empty.',
              style: TextStyle(fontSize: 10, color: Color(0xffc3b5a5)),
            ),
          ),
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
    if (lower.contains('tiktok')) return Colors.black;
    return AppColors.green;
  }
}

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last 7 days',
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 18),
          MiniBarChart(values: values, compact: true),
        ],
      ),
    );
  }
}
