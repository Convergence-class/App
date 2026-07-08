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
    final question = questions.isEmpty ? null : questions[index];
    final text = question == null
        ? '문항을 불러오는 중입니다...'
        : _questionText(question);
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
                  'CES-D 자가진단',
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
                            '지난 1주일 동안,',
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
                          const SizedBox(height: 14),
                          const Text(
                            '각 문항에 대해 지난 일주일 동안 얼마나 자주 그랬는지 선택해주세요. 역채점 문항은 서버에서 자동 계산됩니다.',
                            style: TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),
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
                            title: '극히 드물다',
                            subtitle: '1일 이하',
                            onTap: () => _select(0),
                          ),
                          _ChoiceTile(
                            selected: selected == 1,
                            title: '가끔 있었다',
                            subtitle: '1-2일',
                            onTap: () => _select(1),
                          ),
                          _ChoiceTile(
                            selected: selected == 2,
                            title: '자주 있었다',
                            subtitle: '3-4일',
                            onTap: () => _select(2),
                          ),
                          _ChoiceTile(
                            selected: selected == 3,
                            title: '대부분 그랬다',
                            subtitle: '5-7일',
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
                            ? (submitting ? '제출 중...' : '결과 제출')
                            : '다음 문항',
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

  String _questionText(Map<String, dynamic> question) {
    final no = asInt(question['no'], index + 1);
    return _koreanQuestions[no] ?? question['text']?.toString() ?? '';
  }
}

const _koreanQuestions = {
  1: '평소에는 아무렇지도 않던 일들이 귀찮고 신경 쓰였다.',
  2: '먹고 싶지 않았다. 식욕이 없었다.',
  3: '가족이나 친구가 도와주어도 울적한 기분을 떨쳐버릴 수 없었다.',
  4: '다른 사람들만큼 능력이 있다고 느꼈다.',
  5: '하고 있는 일에 마음을 집중하기 어려웠다.',
  6: '우울하다고 느꼈다.',
  7: '하는 일마다 힘들게 느껴졌다.',
  8: '앞날에 대해 희망적으로 느꼈다.',
  9: '내 인생은 실패작이라고 생각했다.',
  10: '두려움을 느꼈다.',
  11: '잠을 설쳤다.',
  12: '행복하다고 느꼈다.',
  13: '평소보다 말을 적게 했다.',
  14: '외로움을 느꼈다.',
  15: '사람들이 나에게 차갑게 대한다고 느꼈다.',
  16: '생활이 즐거웠다.',
  17: '갑자기 울음이 나왔다.',
  18: '슬픔을 느꼈다.',
  19: '사람들이 나를 싫어한다고 느꼈다.',
  20: '도무지 무슨 일이든 시작하기가 힘들었다.',
};

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
                '${(progress * 100).round()}% 완료',
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
    final info = _levelInfo(score);
    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CES-D 자가진단 결과',
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$score / 60점',
            style: const TextStyle(
              color: AppColors.amber,
              fontWeight: FontWeight.w900,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            info.title,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            info.description,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '이 결과는 의학적 진단이 아니라 선별 검사입니다. 점수가 높거나 힘든 상태가 계속되면 전문가 상담, 학교/직장 상담실, 가까운 정신건강복지센터의 도움을 받아보세요.',
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          YellowButton(label: '다시 검사하기', onPressed: onRestart),
        ],
      ),
    );
  }

  _LevelInfo _levelInfo(int score) {
    if (score <= 15) {
      return const _LevelInfo(
        '정상 범위',
        '최근 1주일 기준으로 우울 관련 증상이 두드러지게 높지는 않습니다. 다만 수면, 식사, 집중력, 대인관계 변화는 계속 관찰해보는 것이 좋아요.',
      );
    }
    if (score <= 24) {
      return const _LevelInfo(
        '경미한 우울 상태 가능성',
        '우울감, 의욕 저하, 피로감, 수면 불편, 집중 어려움이 어느 정도 나타났을 수 있습니다. 휴식과 생활 리듬을 먼저 점검하고, 2주 이상 지속되면 상담을 권장합니다.',
      );
    }
    return const _LevelInfo(
      '높은 우울 상태 가능성',
      '우울감이나 무기력, 수면 문제, 일상 시작의 어려움이 비교적 뚜렷할 수 있습니다. 혼자 견디기보다 신뢰할 수 있는 사람에게 알리고, 가능한 빠르게 전문 상담이나 진료를 받아보는 것이 좋습니다.',
    );
  }
}

class _LevelInfo {
  const _LevelInfo(this.title, this.description);
  final String title;
  final String description;
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
