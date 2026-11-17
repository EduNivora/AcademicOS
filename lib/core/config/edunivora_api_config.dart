class EdunivoraApiConfig {
  EdunivoraApiConfig._();

  static const String noticesBaseUrl =
      'https://br-late-bread-bajll3is-notices.compute.c-8.eu-central-1.aws.neon.tech';

  static const String guestMetricsProxyBaseUrl = String.fromEnvironment(
    'EDUNIVORA_GUEST_METRICS_PROXY_URL',
    defaultValue: '',
  );

  static const String authBaseUrl =
      'https://ep-dry-leaf-baac97v8.neonauth.c-8.eu-central-1.aws.neon.tech/edunivora/auth';
}
