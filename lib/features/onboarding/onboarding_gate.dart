import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'onboarding_screen.dart';

/// Introduces the browsing shell without intercepting property or login links.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'darna_onboarding_v1_completed';
  static bool _completedThisSession = false;
  late final Future<bool> _completed = _readCompleted();

  Future<bool> _readCompleted() async {
    if (_completedThisSession) return true;
    try {
      return await _storage.read(key: _key) == 'true';
    } catch (_) {
      // Browsing must remain available when device storage is unavailable.
      return true;
    }
  }

  Future<void> _finish() async {
    _completedThisSession = true;
    try {
      await _storage.write(key: _key, value: 'true');
    } catch (_) {
      // The in-memory flag still prevents repeats during this session.
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_completedThisSession) return widget.child;
    return FutureBuilder<bool>(
      future: _completed,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // Same look as the native launch screen, so there is no white flash in between.
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.primary,
            body: Center(
              child: Image.asset('assets/branding/darna_mark.webp', width: 128, excludeFromSemantics: true),
            ),
          );
        }
        return snapshot.data!
            ? widget.child
            : OnboardingScreen(onComplete: _finish);
      },
    );
  }
}
