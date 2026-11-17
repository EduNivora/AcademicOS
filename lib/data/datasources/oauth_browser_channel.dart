import 'package:flutter/services.dart';

abstract class OAuthBrowserLauncher {
  void setCallbacks({
    required void Function(Uri deepLink) onDeepLink,
    required void Function() onCustomTabClosed,
  });

  Future<void> launchCustomTab(Uri authorizationUrl);

  Future<Uri?> consumeInitialDeepLink();

  void clearCallbacks();
}

class MethodChannelOAuthBrowserLauncher implements OAuthBrowserLauncher {
  static const String channelName = 'com.arfatalkamli.academicos/oauth_browser';

  final MethodChannel _channel;
  void Function(Uri deepLink)? _onDeepLink;
  void Function()? _onCustomTabClosed;

  MethodChannelOAuthBrowserLauncher({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onDeepLink':
        final raw = call.arguments;
        if (raw is String && raw.isNotEmpty) {
          final uri = Uri.tryParse(raw);
          if (uri != null) {
            _onDeepLink?.call(uri);
          }
        }
        break;
      case 'onCustomTabClosed':
        _onCustomTabClosed?.call();
        break;
    }
  }

  @override
  void setCallbacks({
    required void Function(Uri deepLink) onDeepLink,
    required void Function() onCustomTabClosed,
  }) {
    _onDeepLink = onDeepLink;
    _onCustomTabClosed = onCustomTabClosed;
  }

  @override
  Future<void> launchCustomTab(Uri authorizationUrl) async {
    await _channel.invokeMethod<bool>('launchCustomTab', {
      'url': authorizationUrl.toString(),
    });
  }

  @override
  Future<Uri?> consumeInitialDeepLink() async {
    try {
      final raw = await _channel.invokeMethod<String>('consumeInitialDeepLink');
      if (raw == null || raw.isEmpty) return null;
      return Uri.tryParse(raw);
    } on MissingPluginException {
      return null;
    }
  }

  @override
  void clearCallbacks() {
    _onDeepLink = null;
    _onCustomTabClosed = null;
  }
}
