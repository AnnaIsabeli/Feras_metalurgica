class AppConfig {
  AppConfig({
    required this.databaseUrl,
    required this.devAuth,
    required this.host,
    required this.port,
    required this.allowedOrigin,
  });

  factory AppConfig.fromEnvironment(Map<String, String> env) {
    final development = (env['APP_ENV'] ?? 'production') == 'development';
    final devAuth = env['DEV_AUTH_ENABLED'] == 'true';
    if (devAuth && !development) {
      throw StateError(
        'Autenticação demonstrativa só é permitida em development.',
      );
    }
    final databaseUrl = env['DATABASE_URL'];
    if (databaseUrl == null || databaseUrl.isEmpty) {
      throw StateError('Configure DATABASE_URL. Consulte .env.example.');
    }
    return AppConfig(
      databaseUrl: databaseUrl,
      devAuth: devAuth,
      host: env['HOST'] ?? '127.0.0.1',
      port: int.parse(env['PORT'] ?? '8080'),
      allowedOrigin: env['CORS_ORIGIN'] ?? 'http://localhost:5000',
    );
  }
  final String databaseUrl;
  final bool devAuth;
  final String host;
  final int port;
  final String allowedOrigin;
}
