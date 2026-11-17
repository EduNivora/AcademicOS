import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

typedef ExternalUrlOpener = Future<bool> Function(Uri uri);
typedef ClipboardWriter = Future<void> Function(String text);

class ExternalLinkService {
  ExternalLinkService._();

  static const MethodChannel _channel = MethodChannel(
    'com.arfatalkamli.academicos/external_links',
  );

  /// Validates that [uri] uses only `https` (with non-empty host)
  /// or `mailto` (with non-empty recipient path).
  static bool isSafeExternalUri(Uri? uri) {
    if (uri == null) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'https') {
      return uri.host.trim().isNotEmpty;
    }
    if (scheme == 'mailto') {
      return uri.path.trim().isNotEmpty;
    }
    return false;
  }

  static Uri? parseSafeExternalUri(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    return isSafeExternalUri(uri) ? uri : null;
  }

  static String _clipboardValueForUri(Uri uri) {
    if (uri.scheme.toLowerCase() == 'mailto' && uri.query.isEmpty) {
      return uri.path;
    }
    return uri.toString();
  }

  static Future<bool> _defaultPlatformOpen(Uri uri) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>(
        'openUrl',
        <String, Object>{'url': uri.toString()},
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _defaultClipboardWriter(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  /// Headless/unit-testable variant without requiring a [BuildContext].
  /// Returns `true` when [urlOpener] launches the validated URI, otherwise
  /// falls back to [clipboardWriter] for valid URIs and returns `false`.
  static Future<bool> openUrlTestable(
    String rawUrl, {
    ExternalUrlOpener? urlOpener,
    ClipboardWriter? clipboardWriter,
  }) async {
    final uri = parseSafeExternalUri(rawUrl);
    if (uri == null) return false;

    final opener = urlOpener ?? _defaultPlatformOpen;
    bool opened = false;
    try {
      opened = await opener(uri);
    } catch (_) {
      opened = false;
    }

    if (opened) return true;

    final writer = clipboardWriter ?? _defaultClipboardWriter;
    await writer(_clipboardValueForUri(uri));
    return false;
  }

  /// Safely opens [rawUrl] via the native Android channel (`https` / `mailto`
  /// only). If launching is unavailable or fails, copies the link cleanly to
  /// the clipboard and shows a floating SnackBar.
  static Future<bool> openUrl(
    BuildContext context,
    String rawUrl, {
    String? label,
    ExternalUrlOpener? urlOpener,
    ClipboardWriter? clipboardWriter,
  }) async {
    final isArabic = _isArabicContext(context);
    final uri = parseSafeExternalUri(rawUrl);

    if (uri == null) {
      _showFeedback(
        context,
        isArabic
            ? 'تعذر فتح الرابط لأن صيغته غير مدعومة.'
            : 'Unable to open link because the URL scheme is not supported.',
        isError: true,
      );
      return false;
    }

    final opener = urlOpener ?? _defaultPlatformOpen;
    bool opened = false;
    try {
      opened = await opener(uri);
    } catch (_) {
      opened = false;
    }

    if (opened) {
      return true;
    }

    final copyValue = _clipboardValueForUri(uri);
    final writer = clipboardWriter ?? _defaultClipboardWriter;
    await writer(copyValue);

    if (context.mounted) {
      final hasLabel = label != null && label.trim().isNotEmpty;
      final message = isArabic
          ? (hasLabel
                ? 'تعذر فتح التطبيق الخارجي — تم نسخ $label إلى الحافظة'
                : 'تم نسخ الرابط إلى الحافظة')
          : (hasLabel
                ? 'Could not launch external app — copied $label to clipboard'
                : 'Link copied to clipboard');
      _showFeedback(context, message);
    }

    return false;
  }

  static Future<void> copyToClipboard(
    BuildContext context,
    String text, {
    String? feedbackMessage,
    ClipboardWriter? clipboardWriter,
  }) async {
    final writer = clipboardWriter ?? _defaultClipboardWriter;
    await writer(text);

    if (!context.mounted) return;
    final isArabic = _isArabicContext(context);
    final message =
        feedbackMessage ??
        (isArabic ? 'تم النسخ إلى الحافظة' : 'Copied to clipboard');
    _showFeedback(context, message);
  }

  static bool _isArabicContext(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    if (locale?.languageCode.toLowerCase() == 'ar') {
      return true;
    }
    return Directionality.of(context) == TextDirection.rtl;
  }

  static void _showFeedback(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppTheme.danger : AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }
}
