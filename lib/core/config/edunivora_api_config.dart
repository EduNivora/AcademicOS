class EdunivoraApiConfig {
  EdunivoraApiConfig._();

  static const String noticesBaseUrl =
      'https://br-late-bread-bajll3is-notices.compute.c-8.eu-central-1.aws.neon.tech';

  static const String authBaseUrl =
      'https://ep-dry-leaf-baac97v8.neonauth.c-8.eu-central-1.aws.neon.tech/edunivora/auth';

  /// Least-privilege loopback origin registered in Neon Auth Trusted Domains.
  static const int oauthLoopbackPort = 43821;
  static const String oauthLoopbackOrigin =
      'http://localhost:$oauthLoopbackPort';
  static const String oauthCallbackPath = '/auth/callback';
  static const String oauthErrorPath = '/auth/error';

  /// Android Deep Link used to dismiss Chrome Custom Tabs and return to the app.
  static const String oauthDeepLinkScheme = 'edunivora';
  static const String oauthDeepLinkHost = 'auth';
  static const String oauthDeepLinkCallbackPath = '/callback';
}
