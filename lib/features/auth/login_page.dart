import 'package:flutter/material.dart';

import 'package:emotion_app/core/config/api_config.dart';
import 'package:emotion_app/core/theme/app_colors.dart';
import 'package:emotion_app/data/api/backend_api.dart';
import 'package:emotion_app/features/shell/app_shell.dart';
import 'package:emotion_app/shared/widgets/app_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final api = BackendApi();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLogin = true;
  bool loading = false;
  String? message;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nickname = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty || (!isLogin && nickname.isEmpty)) {
      setState(
        () => message = isLogin
            ? '이메일과 비밀번호를 입력해주세요.'
            : '이름, 이메일, 비밀번호를 모두 입력해주세요.',
      );
      return;
    }

    if (!isLogin) {
      final agreed = await _showSignupConsentDialog();
      if (agreed != true) return;
    }

    setState(() {
      loading = true;
      message = null;
    });

    try {
      if (!isLogin) {
        await api.signUp(email: email, password: password, nickname: nickname);
      }
      await api.login(email: email, password: password);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
    } catch (error) {
      if (!mounted) return;
      setState(() => message = error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<bool?> _showSignupConsentDialog() {
    var personal = false;
    var data = false;
    var notification = false;
    var chatbot = false;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allRequired = personal && data;
            return AlertDialog(
              title: const Text('회원가입 동의'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      value: personal,
                      onChanged: (value) =>
                          setModalState(() => personal = value ?? false),
                      title: const Text('필수: 개인정보 수집 동의'),
                      subtitle: const Text('계정 생성과 서비스 제공을 위해 필요합니다.'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      value: data,
                      onChanged: (value) =>
                          setModalState(() => data = value ?? false),
                      title: const Text('필수: 사용시간 및 자가진단 데이터 처리 동의'),
                      subtitle: const Text('사용시간 분석과 CES-D 결과 저장에 필요합니다.'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      value: notification,
                      onChanged: (value) =>
                          setModalState(() => notification = value ?? false),
                      title: const Text('선택: 사용시간 알림 동의'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      value: chatbot,
                      onChanged: (value) =>
                          setModalState(() => chatbot = value ?? false),
                      title: const Text('선택: AI 챗봇 이용 동의'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: allRequired
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: const Text('동의하고 가입'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          child: Column(
            children: [
              const SizedBox(height: 4),
              const AppLogo(),
              const SizedBox(height: 28),
              const Text(
                '디지털 균형으로\n마음의 여유를 찾아보세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 24,
                  height: 1.35,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '스마트폰 사용을 건강하게 관리하고,\n나의 감정과 마음을 돌보는 여정을 함께해요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 12,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              _AuthCard(
                isLogin: isLogin,
                loading: loading,
                message: message,
                nameController: nameController,
                emailController: emailController,
                passwordController: passwordController,
                onTabChanged: (value) => setState(() {
                  isLogin = value;
                  message = null;
                }),
                onSubmit: _submit,
              ),
              const SizedBox(height: 8),
              Text(
                'API: ${ApiConfig.baseUrl}',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.isLogin,
    required this.loading,
    required this.message,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.onTabChanged,
    required this.onSubmit,
  });

  final bool isLogin;
  final bool loading;
  final String? message;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final ValueChanged<bool> onTabChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _AuthTab(
                label: '로그인',
                selected: isLogin,
                onTap: () => onTabChanged(true),
              ),
              _AuthTab(
                label: '회원가입',
                selected: !isLogin,
                onTap: () => onTabChanged(false),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!isLogin) ...[
            _AuthField(
              controller: nameController,
              icon: Icons.person_outline_rounded,
              hint: '이름을 입력해주세요',
            ),
            const SizedBox(height: 10),
          ],
          _AuthField(
            controller: emailController,
            icon: Icons.mail_outline_rounded,
            hint: '이메일을 입력해주세요',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          _AuthField(
            controller: passwordController,
            icon: Icons.lock_outline_rounded,
            hint: '비밀번호를 입력해주세요',
            obscure: true,
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          YellowButton(
            label: loading ? '잠시만요...' : (isLogin ? '로그인' : '회원가입'),
            onPressed: loading ? null : onSubmit,
          ),
          const SizedBox(height: 10),
          YellowButton(
            label: isLogin ? '회원가입' : '로그인으로 돌아가기',
            filled: false,
            onPressed: loading ? null : () => onTabChanged(!isLogin),
          ),
        ],
      ),
    );
  }
}

class _AuthTab extends StatelessWidget {
  const _AuthTab({
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.amber : AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              height: 1.5,
              color: selected ? AppColors.amber : AppColors.line,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.field,
        prefixIcon: Icon(icon, color: AppColors.mutedText, size: 20),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xff9b8f80), fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
      ),
    );
  }
}
