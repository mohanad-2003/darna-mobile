import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_controller.dart';
import '../auth/login_screen.dart';
import 'onboarding_screen.dart';

const _onboardingKey = 'darna_onboarding_v1_completed';

/// Decides what the first screen is when the app opens:
///
/// * first launch after install: the onboarding slides, then the login screen;
/// * later launches: the launch splash, then the login screen when nobody is signed in,
///   or the app itself when a session exists;
/// * "تصفح كزائر" on the login screen lets people browse without an account, for this
///   launch only.
///
/// Links to a property or to /login do not go through this gate.
class OnboardingGate extends ConsumerStatefulWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;

  /// True once this launch has got past the start screens; the gate then stays out of the way
  /// (for example after sign-out, the user stays where they are).
  static bool _entered = false;

  @visibleForTesting
  static void resetForTest() => _entered = false;

  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _Start {
  const _Start({required this.onboarded, required this.hasSession});

  final bool onboarded;
  final bool hasSession;
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  // Not secure storage: the keystore/keychain can outlive an uninstall, and a reinstall
  // must show the slides again. A plain preference goes away with the app's data.
  late final Future<_Start> _start = _read();
  bool _onboardedNow = false;

  Future<_Start> _read() async {
    var onboarded = true; // Browsing must stay available when storage fails.
    try {
      onboarded = (await SharedPreferences.getInstance()).getBool(_onboardingKey) ?? false;
    } catch (_) {}
    var hasSession = false;
    try {
      hasSession = await ref.read(tokenStoreProvider).refreshToken != null;
    } catch (_) {}
    return _Start(onboarded: onboarded, hasSession: hasSession);
  }

  Future<void> _finishOnboarding() async {
    _onboardedNow = true; // Still applies this session if the write below fails.
    try {
      await (await SharedPreferences.getInstance()).setBool(_onboardingKey, true);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authControllerProvider).value != null;
    if (OnboardingGate._entered) return widget.child;

    return FutureBuilder<_Start>(
      future: _start,
      builder: (context, snapshot) {
        final start = snapshot.data;
        if (start == null) {
          // Same look as the native launch screen, so there is no white flash in between.
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.primary,
            body: Center(
              child: SvgPicture.asset(
                'assets/branding/darna_symbol_dark.svg',
                width: 128,
                excludeFromSemantics: true,
              ),
            ),
          );
        }
        if (!start.onboarded && !_onboardedNow) {
          return OnboardingScreen(onComplete: _finishOnboarding);
        }
        // Signing in (from the login screen here, or anywhere else) ends the start flow.
        // This comes after the slides on purpose: a reinstall can keep an old session in the
        // keychain, and a fresh install must still show the slides.
        if (start.hasSession || signedIn) {
          OnboardingGate._entered = true;
          return widget.child;
        }
        return LoginScreen(onSkip: () => setState(() => OnboardingGate._entered = true));
      },
    );
  }
}
