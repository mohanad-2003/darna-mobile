import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config.dart';

void main() {
  // A release build without a public https API address must not start.
  AppConfig.ensureValid();
  runApp(const ProviderScope(child: DarnaApp()));
}
