class AppSession {
  static final AppSession instance = AppSession._();

  AppSession._();

  String? accessToken;
  String? userId;
  String? email;

  bool get isLoggedIn => accessToken != null && userId != null;

  Future<void> load() async {
    // In-memory session for backend connection testing.
  }

  Future<void> save({
    required String token,
    required String userId,
    required String email,
  }) async {
    accessToken = token;
    this.userId = userId;
    this.email = email;
  }

  Future<void> clear() async {
    accessToken = null;
    userId = null;
    email = null;
  }
}
