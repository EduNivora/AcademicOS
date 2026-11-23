class EdunivoraApiConfig {
  EdunivoraApiConfig._();

  static const String noticesBaseUrl =
      'https://edunivora-guest-metrics.m-gh-alaosimi.workers.dev';

  static const String aiBaseUrl =
      'https://br-late-bread-bajll3is-ai.compute.c-8.eu-central-1.aws.neon.tech';

  static const String authBaseUrl =
      'https://ep-dry-leaf-baac97v8.neonauth.c-8.eu-central-1.aws.neon.tech/edunivora/auth';

  static const int oauthLoopbackPort = 43821;
  static const String oauthLoopbackOrigin = 'http://localhost:$oauthLoopbackPort';
  static const String oauthCallbackPath = '/auth/callback';
  static const String oauthErrorPath = '/auth/error';
  static const String oauthDeepLinkScheme = 'edunivora';
  static const String oauthDeepLinkHost = 'auth';
  static const String oauthDeepLinkCallbackPath = '/callback';
}
