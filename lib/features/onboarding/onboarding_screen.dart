import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/widgets/darna_logo.dart';

// The illustrations are drawn on this cream; using it for the screen hides the image edges.
const _ivory = Color(0xFFFAF6F1);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _busy = false;

  static const _slides = [
    (
      image: 'assets/onboarding/discover.webp',
      label: 'مكان جديد، بداية جديدة',
      title: 'دارك أقرب مما تتخيّل',
      description: 'اكتشف شققًا ومنازل وأراضي للبيع أو للإيجار، وابحث حسب المنطقة والسعر وما يناسبك.',
    ),
    (
      image: 'assets/onboarding/connect.webp',
      label: 'خياراتك في مكان واحد',
      title: 'احفظ ما يعجبك، وتواصل',
      description: 'أضف العقارات إلى مفضلتك لتعود إليها بسهولة، وتواصل مع المعلن لمعرفة التفاصيل.',
    ),
    (
      image: 'assets/onboarding/publish.webp',
      label: 'لعقارك فرصة جديدة',
      title: 'اعرض عقارك بخطوات بسيطة',
      description: 'أضف الصور والتفاصيل وحدّد الموقع، ثم أرسل إعلانك للمراجعة ليظهر للباحثين عن عقار.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      await widget.onComplete();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always light: the illustrations are painted on cream and would clash with a dark theme.
    return Theme(data: AppTheme.light(), child: Builder(builder: _buildLight));
  }

  Widget _buildLight(BuildContext context) {
    final theme = Theme.of(context);
    final teal = theme.colorScheme.primary;
    return Scaffold(
      backgroundColor: _ivory,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const DarnaLogo(height: 44, onLight: true), // this screen is always light
                      TextButton(
                        onPressed: _busy ? null : _finish,
                        child: const Text('تخطي'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (value) => setState(() => _page = value),
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 12,
                            ),
                            child: Column(
                              children: [
                                Image.asset(
                                  slide.image,
                                  height: (constraints.maxHeight * .58).clamp(
                                    140.0,
                                    360.0,
                                  ),
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  excludeFromSemantics: true,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  slide.label,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: teal,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Semantics(
                                  header: true,
                                  child: Text(
                                    slide.title,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                          color: const Color(0xFF173F3A),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  slide.description,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: const Color(0xFF526761),
                                    height: 1.65,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
                  child: Column(
                    children: [
                      Semantics(
                        label: 'الصفحة ${_page + 1} من ${_slides.length}',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _slides.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: index == _page ? 26 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: index == _page
                                    ? teal
                                    : const Color(0xFFD2DFD9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 17,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: _busy
                              ? null
                              : () async {
                                  if (_page == _slides.length - 1) {
                                    await _finish();
                                  } else {
                                    await _controller.nextPage(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                },
                          child: Text(
                            _page == _slides.length - 1
                                ? 'ابدأ الآن'
                                : 'التالي',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
