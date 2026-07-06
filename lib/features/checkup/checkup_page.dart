import 'package:flutter/material.dart';

import 'package:emotion_app/core/theme/app_colors.dart';
import 'package:emotion_app/data/api/api_helpers.dart';
import 'package:emotion_app/data/api/backend_api.dart';
import 'package:emotion_app/shared/widgets/app_widgets.dart';

class CheckupPage extends StatefulWidget {
  const CheckupPage({super.key});

  @override
  State<CheckupPage> createState() => _CheckupPageState();
}

class _CheckupPageState extends State<CheckupPage> {
  final api = BackendApi();
  bool loading = true;
  bool submitting = false;
  String? error;
  List<Map<String, dynamic>> questions = [];
  List<int> answers = [];
  int index = 0;
  Map<String, dynamic>? result;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await api.getCesdQuestions();
      final loaded = asMapList(response['data']);
      if (!mounted) return;
      setState(() {
        questions = loaded;
        answers = List<int>.filled(loaded.length, -1);
        index = 0;
        result = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _next() async {
    if (answers.isEmpty || answers[index] == -1) return;
    if (index < questions.length - 1) {
      setState(() => index += 1);
      return;
    }

    setState(() {
      submitting = true;
      error = null;
    });
    try {
      final response = await api.submitCesd(answers);
      if (!mounted) return;
      setState(() => result = asMap(response['data']));
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  void _select(int value) {
    if (answers.isEmpty) return;
    setState(() => answers[index] = value);
  }

  @override
  Widget build(BuildContext context) {
    final total = questions.isEmpty ? 20 : questions.length;
    final text = questions.isEmpty
        ? 'Loading question...'
        : questions[index]['text']?.toString() ?? '';
    final selected = answers.isEmpty ? -1 : answers[index];

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Row(
              children: [
                IconButton(
                  onPressed: index > 0 && result == null
                      ? () => setState(() => index -= 1)
                      : null,
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'CES-D Check',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (loading || submitting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                children: [
                  _ProgressHeader(current: index + 1, total: total),
                  if (error != null)
                    _ErrorCard(message: error!, onRetry: _loadQuestions),
                  if (result != null)
                    _ResultCard(result: result!, onRestart: _loadQuestions),
                  if (result == null)
                    DesignCard(
                      margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'During the past week,',
                            style: TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            text,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Center(
                            child: CircleAvatar(
                              radius: 34,
                              backgroundColor: AppColors.blueSoft,
                              child: Icon(
                                Icons.mood_bad_rounded,
                                color: AppColors.amber,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _ChoiceTile(
                            selected: selected == 0,
                            title: 'Rarely',
                            subtitle: 'Less than 1 day',
                            onTap: () => _select(0),
                          ),
                          _ChoiceTile(
                            selected: selected == 1,
                            title: 'Some days',
                            subtitle: '1-2 days',
                            onTap: () => _select(1),
                          ),
                          _ChoiceTile(
                            selected: selected == 2,
                            title: 'Often',
                            subtitle: '3-4 days',
                            onTap: () => _select(2),
                          ),
                          _ChoiceTile(
                            selected: selected == 3,
                            title: 'Most days',
                            subtitle: '5-7 days',
                            onTap: () => _select(3),
                          ),
                        ],
                      ),
                    ),
                  if (result == null) _QuestionDots(index: index, total: total),
                  if (result == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: YellowButton(
                        label: index == total - 1
                            ? (submitting ? 'Submitting...' : 'Submit result')
                            : 'Next question',
                        onPressed: selected == -1 || submitting || loading
                            ? null
                            : _next,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : current / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$current / $total',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}% done',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.line,
              valueColor: const AlwaysStoppedAnimation(AppColors.amber),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.amberSoft : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.amber : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.amber : AppColors.line,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionDots extends StatelessWidget {
  const _QuestionDots({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final start = (index ~/ 7) * 7;
    final count = total - start > 7 ? 7 : total - start;
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(count, (offset) {
          final questionIndex = start + offset;
          final active = questionIndex == index;
          return CircleAvatar(
            radius: 13,
            backgroundColor: active ? AppColors.amber : const Color(0xffd9cdb9),
            child: Text(
              '${questionIndex + 1}',
              style: TextStyle(
                color: active ? Colors.white : AppColors.mutedText,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onRestart});

  final Map<String, dynamic> result;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final score = asInt(result['score']);
    final level = result['level']?.toString() ?? '-';
    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Result submitted',
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Score $score/60',
            style: const TextStyle(
              color: AppColors.amber,
              fontWeight: FontWeight.w900,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            level,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          YellowButton(label: 'Restart', onPressed: onRestart),
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
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
