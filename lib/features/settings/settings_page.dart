import 'package:flutter/material.dart';

import 'package:emotion_app/core/theme/app_colors.dart';
import 'package:emotion_app/data/api/api_helpers.dart';
import 'package:emotion_app/data/api/backend_api.dart';
import 'package:emotion_app/data/session/app_session.dart';
import 'package:emotion_app/features/auth/login_page.dart';
import 'package:emotion_app/shared/widgets/app_widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final api = BackendApi();
  bool loading = true;
  bool saving = false;
  String? message;
  bool dataCollection = true;
  bool notification = true;
  bool chatbotOptin = false;
  bool cesdCard = true;
  bool chatbotCard = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      message = null;
    });
    try {
      final consent = await _ignoreNotFound(api.getConsent());
      final data = asMap(consent?['data']);
      final status = await _ignoreNotFound(api.getCardStatus());
      if (!mounted) return;
      setState(() {
        dataCollection = asBool(data?['data_collection'], dataCollection);
        notification = asBool(data?['notification'], notification);
        chatbotOptin = asBool(data?['chatbot_optin'], chatbotOptin);
        cesdCard = asBool(status?['showCESDCard'], cesdCard);
        chatbotCard = asBool(status?['showChatbotCard'], chatbotCard);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<Map<String, dynamic>?> _ignoreNotFound(
    Future<Map<String, dynamic>> future,
  ) async {
    try {
      return await future;
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    setState(() {
      saving = true;
      message = null;
    });
    try {
      await api.saveConsent(
        dataCollection: dataCollection,
        notification: notification,
        chatbotOptin: chatbotOptin,
      );
      if (!mounted) return;
      setState(() => message = '설정이 서버에 저장되었습니다.');
    } catch (e) {
      if (!mounted) return;
      setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _logout() async {
    await api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const AppHeader(title: '설정'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  children: [
                    _ProfileCard(onLogout: _logout),
                    if (message != null) _MessageCard(message: message!),
                    _ConsentCard(
                      loading: loading,
                      dataCollection: dataCollection,
                      notification: notification,
                      chatbotOptin: chatbotOptin,
                      onDataCollectionChanged: (value) =>
                          setState(() => dataCollection = value),
                      onNotificationChanged: (value) =>
                          setState(() => notification = value),
                      onChatbotChanged: (value) =>
                          setState(() => chatbotOptin = value),
                    ),
                    _VisibilityCard(
                      cesdCard: cesdCard,
                      chatbotCard: chatbotCard,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: YellowButton(
                        label: saving ? '저장 중...' : '설정 저장',
                        onPressed: saving ? null : _save,
                      ),
                    ),
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final session = AppSession.instance;
    return DesignCard(
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.blueSoft,
            child: Text('🙂', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '김마인드',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  session.email ?? '로그인 사용자',
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
                Text(
                  session.userId ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onLogout,
            child: const Text('로그아웃', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isError =
        message.contains('Exception') ||
        message.contains('[') ||
        message.contains('실패');
    return DesignCard(
      color: isError ? const Color(0xfffff4f2) : const Color(0xfff4fff5),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? Colors.redAccent : AppColors.green,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.loading,
    required this.dataCollection,
    required this.notification,
    required this.chatbotOptin,
    required this.onDataCollectionChanged,
    required this.onNotificationChanged,
    required this.onChatbotChanged,
  });

  final bool loading;
  final bool dataCollection;
  final bool notification;
  final bool chatbotOptin;
  final ValueChanged<bool> onDataCollectionChanged;
  final ValueChanged<bool> onNotificationChanged;
  final ValueChanged<bool> onChatbotChanged;

  @override
  Widget build(BuildContext context) {
    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '개인정보 수집 동의',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
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
          const SizedBox(height: 4),
          const Text(
            '서비스 이용을 위해 아래 항목에 동의해주세요.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 11),
          ),
          const SizedBox(height: 12),
          _SettingSwitch(
            icon: Icons.shield_outlined,
            title: '개인정보 수집 동의',
            subtitle: '서비스 이용을 위한 필수 항목입니다.',
            enabled: dataCollection,
            onChanged: onDataCollectionChanged,
          ),
          _SettingSwitch(
            icon: Icons.notifications_none_rounded,
            title: '알림 수신 동의',
            subtitle: '중요 알림 및 주기적 안내를 받습니다.',
            enabled: notification,
            onChanged: onNotificationChanged,
          ),
          _SettingSwitch(
            icon: Icons.smart_toy_outlined,
            title: '챗봇 이용 동의',
            subtitle: 'AI 챗봇 서비스 이용에 동의합니다.',
            enabled: chatbotOptin,
            onChanged: onChatbotChanged,
          ),
        ],
      ),
    );
  }
}

class _VisibilityCard extends StatelessWidget {
  const _VisibilityCard({required this.cesdCard, required this.chatbotCard});

  final bool cesdCard;
  final bool chatbotCard;

  @override
  Widget build(BuildContext context) {
    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '카드 노출 상태',
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '서버가 판단한 홈 카드 노출 상태입니다.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 11),
          ),
          const SizedBox(height: 12),
          _ReadOnlyStatus(
            icon: Icons.assignment_outlined,
            title: 'CES-D 카드',
            visible: cesdCard,
          ),
          _ReadOnlyStatus(
            icon: Icons.smart_toy_outlined,
            title: '챗봇 카드',
            visible: chatbotCard,
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyStatus extends StatelessWidget {
  const _ReadOnlyStatus({
    required this.icon,
    required this.title,
    required this.visible,
  });

  final IconData icon;
  final String title;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: visible ? AppColors.blueSoft : AppColors.line,
            child: Icon(
              icon,
              size: 18,
              color: visible ? AppColors.navy : AppColors.mutedText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            visible ? '표시' : '숨김',
            style: TextStyle(
              color: visible ? AppColors.amber : AppColors.mutedText,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: enabled ? AppColors.blueSoft : AppColors.line,
            child: Icon(
              icon,
              size: 18,
              color: enabled ? AppColors.navy : AppColors.mutedText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
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
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.amber,
          ),
        ],
      ),
    );
  }
}
