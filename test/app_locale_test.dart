import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:academic_os/core/localization/app_locale.dart';

void main() {
  test('Arabic selection uses Arabic locale and RTL direction', () {
    expect(appLocaleForLanguage(true), const Locale('ar', 'SA'));
    expect(appTextDirectionForLanguage(true), TextDirection.rtl);
  });

  test('English selection uses English locale and LTR direction', () {
    expect(appLocaleForLanguage(false), const Locale('en', 'US'));
    expect(appTextDirectionForLanguage(false), TextDirection.ltr);
  });
}
