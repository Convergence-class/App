import 'package:shared_preferences/shared_preferences.dart';

class AppSession {
  static final AppSession instance = AppSession._();

  AppSession._();

  static const _tokenKey = 'session.access_token';
  static const _userIdKey = 'session.user_id';
  static const _emailKey = 'session.email';
  static const _nicknameKey = 'session.nickname';
  static const _chatbotOptInKey = 'session.chatbot_opt_in';

  String? accessToken;
  String? userId;
  String? email;
  String? nickname;
  bool chatbotOptIn = false;

  bool get isLoggedIn =>
      accessToken != null &&
      accessToken!.isNotEmpty &&
      userId != null &&
      userId!.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString(_tokenKey);
    userId = prefs.getString(_userIdKey);
    email = prefs.getString(_emailKey);
    nickname = prefs.getString(_nicknameKey);
    chatbotOptIn = prefs.getBool(_chatbotOptInKey) ?? false;
  }

  Future<void> save({
    required String token,
    required String userId,
    required String email,
    String? nickname,
  }) async {
    final resolvedNickname = nickname?.trim().isNotEmpty == true
        ? nickname!.trim()
        : email.split('@').first;

    accessToken = token;
    this.userId = userId;
    this.email = email;
    this.nickname = resolvedNickname;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_emailKey, email);
    await prefs.setString(_nicknameKey, resolvedNickname);
  }

  Future<void> setChatbotOptIn(bool value) async {
    chatbotOptIn = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chatbotOptInKey, value);
  }

  Future<void> clear() async {
    accessToken = null;
    userId = null;
    email = null;
    nickname = null;
    chatbotOptIn = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_nicknameKey);
    await prefs.remove(_chatbotOptInKey);
  }
}
