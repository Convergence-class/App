import 'package:emotion_app/data/api/api_client.dart';
import 'package:emotion_app/data/session/app_session.dart';

class BackendApi {
  BackendApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<Map<String, dynamic>> health() {
    return _client.get('/', auth: false);
  }

  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String nickname,
  }) {
    return _client.post(
      '/api/auth/signup',
      body: {'email': email, 'password': password, 'nickname': nickname},
      auth: false,
    );
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final result = await _client.post(
      '/api/auth/login',
      body: {'email': email, 'password': password},
      auth: false,
    );
    final token = result['access_token']?.toString();
    final userId = result['user_id']?.toString();
    if (token == null || userId == null) {
      throw const FormatException('로그인 응답에 토큰 또는 사용자 ID가 없습니다.');
    }
    await AppSession.instance.save(
      token: token,
      userId: userId,
      email: result['email']?.toString() ?? email,
      nickname: result['nickname']?.toString(),
    );
    return result;
  }

  Future<void> logout() async {
    try {
      await _client.post('/api/auth/logout');
    } finally {
      await AppSession.instance.clear();
    }
  }

  Future<Map<String, dynamic>> getUsageSummary({String? date}) {
    return _client.get(
      '/api/usage/summary',
      query: {'user_id': _userId, 'date': date},
    );
  }

  Future<Map<String, dynamic>> logUsage({
    required String appName,
    required int durationMinutes,
    DateTime? loggedAt,
  }) {
    return _client.post(
      '/api/usage/log',
      body: {
        'user_id': _userId,
        'app_name': appName,
        'duration_minutes': durationMinutes,
        if (loggedAt != null) 'logged_at': loggedAt.toIso8601String(),
      },
    );
  }

  Future<Map<String, dynamic>> getCesdQuestions() =>
      _client.get('/api/cesd/questions');

  Future<Map<String, dynamic>> submitCesd(List<int> answers) {
    return _client.post(
      '/api/cesd/submit',
      body: {'user_id': _userId, 'answers': answers},
    );
  }

  Future<Map<String, dynamic>> getCesdResult() {
    return _client.get('/api/cesd/result', query: {'user_id': _userId});
  }

  Future<Map<String, dynamic>> sendChatMessage(
    String message, {
    List<Map<String, String>> history = const [],
  }) {
    return _client.post(
      '/api/chat/message',
      body: {'user_id': _userId, 'message': message, 'history': history},
    );
  }

  Future<Map<String, dynamic>> getChatHistory({int limit = 50}) {
    return _client.get(
      '/api/chat/history',
      query: {'user_id': _userId, 'limit': limit},
    );
  }

  Future<Map<String, dynamic>> getRandomNotice() =>
      _client.get('/api/notice/random');

  Future<Map<String, dynamic>> getConsent() {
    return _client.get('/api/consent', query: {'user_id': _userId});
  }

  Future<Map<String, dynamic>> saveConsent({
    required bool dataCollection,
    required bool notification,
    required bool chatbotOptin,
  }) {
    return _client.post(
      '/api/consent',
      body: {
        'user_id': _userId,
        'data_collection': dataCollection,
        'notification': notification,
        'chatbot_optin': chatbotOptin,
      },
    );
  }

  Future<Map<String, dynamic>> getCardStatus() {
    return _client.get('/api/status/cards', query: {'user_id': _userId});
  }

  Future<Map<String, dynamic>> dismissChatbotCard() {
    return _client.post(
      '/api/status/cards/dismiss',
      body: {'user_id': _userId},
    );
  }

  String get _userId {
    final userId = AppSession.instance.userId;
    if (userId == null || userId.isEmpty) {
      throw StateError('로그인이 필요합니다.');
    }
    return userId;
  }
}
