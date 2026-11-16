class EdunivoraApiConfig {
  EdunivoraApiConfig._();

  static const String noticesBaseUrl =
      'https://br-late-bread-bajll3is-notices.compute.c-8.eu-central-1.aws.neon.tech';

  // Set only after the Cloudflare Durable Object guest-metrics proxy is
  // deployed and its upstream Neon secret is configured. Empty means that
  // guest metrics are disabled; public notice reads remain available.
  static const String guestMetricsProxyBaseUrl = String.fromEnvironment(
    'EDUNIVORA_GUEST_METRICS_PROXY_URL',
    defaultValue: '',
  );

  static const String authBaseUrl =
      'https://ep-dry-leaf-baac97v8.neonauth.c-8.eu-central-1.aws.neon.tech/edunivora/auth';
}
