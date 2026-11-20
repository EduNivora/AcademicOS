import 'package:flutter/material.dart';

Locale appLocaleForLanguage(bool isArabic) =>
    isArabic ? const Locale('ar', 'SA') : const Locale('en', 'US');

TextDirection appTextDirectionForLanguage(bool isArabic) =>
    isArabic ? TextDirection.rtl : TextDirection.ltr;
