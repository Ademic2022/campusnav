import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/storage_service.dart';

// ─────────────────────────────────────────────────────────
// File-private helpers
// ─────────────────────────────────────────────────────────
Widget _ring(double size, Color color, double bgOpacity,
    {double borderOpacity = 0, double borderWidth = 1}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(bgOpacity),
      border: borderOpacity > 0
          ? Border.all(
              color: color.withOpacity(borderOpacity), width: borderWidth)
          : null,
    ),
  );
}

Widget _dot(double size, Color color) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );

// ─────────────────────────────────────────────────────────
// Onboarding Screen
// ─────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  static const _totalPages = 4;

  void _onPageChanged(int page) {
    HapticFeedback.selectionClick();
    setState(() => _currentPage = page);
  }

  void _next() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await StorageService.instance.markOnboardingSeen();
    if (mounted) context.go('/');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _totalPages - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip ──
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: isLast ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: TextButton(
                      onPressed: isLast ? null : _finish,
                      child: Text(
                        'Skip',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Pages ──
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const BouncingScrollPhysics(),
                children: const [
                  _Page(
                    illustration: _WelcomeIllustration(),
                    title: 'Welcome to\nOAU Navigator',
                    subtitle:
                        'Your smart guide to every corner of the Obafemi Awolowo University campus.',
                  ),
                  _Page(
                    illustration: _DiscoverIllustration(),
                    title: 'Discover Every\nLandmark',
                    subtitle:
                        'Explore hostels, faculties, food spots, health centers, and 100+ campus locations.',
                  ),
                  _Page(
                    illustration: _NavigateIllustration(),
                    title: 'Navigate\nwith Ease',
                    subtitle:
                        'Get step-by-step walking or driving directions to any destination on campus.',
                  ),
                  _Page(
                    illustration: _NearbyIllustration(),
                    title: "Always Know\nWhat's Nearby",
                    subtitle:
                        "Discover landmarks sorted by distance from where you are, updated in real time.",
                  ),
                ],
              ),
            ),

            // ── Bottom: dots + CTA ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 44),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _totalPages,
                      (i) => _ProgressDot(active: i == _currentPage),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.3),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: Text(
                          isLast ? 'Get Started' : 'Next',
                          key: ValueKey(isLast),
                          style: AppTextStyles.titleLarge
                              .copyWith(color: Colors.white),
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
    );
  }
}

// ─────────────────────────────────────────────────────────
// Progress Dot
// ─────────────────────────────────────────────────────────
class _ProgressDot extends StatelessWidget {
  final bool active;
  const _ProgressDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active
            ? AppColors.primary
            : AppColors.textMuted.withOpacity(0.35),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Single page — manages its own entrance animation
// ─────────────────────────────────────────────────────────
class _Page extends StatefulWidget {
  final Widget illustration;
  final String title;
  final String subtitle;

  const _Page({
    required this.illustration,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    )..forward();

    _scale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutBack),
      ),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
      ),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          // Illustration — top ~55%
          Expanded(
            flex: 55,
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Center(child: widget.illustration),
              ),
            ),
          ),
          // Text — bottom ~45%
          Expanded(
            flex: 45,
            child: SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: AppTextStyles.displayLarge),
                    const SizedBox(height: 14),
                    Text(
                      widget.subtitle,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Illustrations
// ─────────────────────────────────────────────────────────

// 1 ── Welcome
class _WelcomeIllustration extends StatelessWidget {
  const _WelcomeIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 270,
      height: 270,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ring(260, AppColors.primary, 0.05,
              borderOpacity: 0.13, borderWidth: 1),
          _ring(196, AppColors.primary, 0.08,
              borderOpacity: 0.22, borderWidth: 1.5),
          // Inner glowing circle
          Container(
            width: 126,
            height: 126,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withOpacity(0.32),
                  AppColors.primary.withOpacity(0.07),
                ],
              ),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.48),
                width: 1.5,
              ),
            ),
          ),
          const Text('🗺️', style: TextStyle(fontSize: 52)),
          // Floating colour dots
          Positioned(
              top: 20,
              left: 54,
              child: _dot(10, AppColors.accent.withOpacity(0.85))),
          Positioned(
              top: 60,
              right: 22,
              child: _dot(8, AppColors.catFaculty.withOpacity(0.75))),
          Positioned(
              bottom: 30,
              left: 26,
              child: _dot(9, AppColors.catHostel.withOpacity(0.75))),
          Positioned(
              bottom: 50,
              right: 44,
              child: _dot(12, AppColors.catFood.withOpacity(0.8))),
          Positioned(
              top: 98,
              left: 12,
              child: _dot(6, AppColors.catHealth.withOpacity(0.6))),
        ],
      ),
    );
  }
}

// 2 ── Discover
class _Cat {
  final String emoji;
  final String label;
  final Color color;
  const _Cat(this.emoji, this.label, this.color);
}

class _CatChip extends StatelessWidget {
  final _Cat cat;
  const _CatChip(this.cat);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cat.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cat.color.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(cat.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            cat.label,
            style: AppTextStyles.labelLarge.copyWith(color: cat.color),
          ),
        ],
      ),
    );
  }
}

class _DiscoverIllustration extends StatelessWidget {
  const _DiscoverIllustration();

  static const _cats = [
    _Cat('🏠', 'Hostel', AppColors.catHostel),
    _Cat('🏛️', 'Faculty', AppColors.catFaculty),
    _Cat('🍽️', 'Food', AppColors.catFood),
    _Cat('🏥', 'Health', AppColors.catHealth),
    _Cat('🏦', 'Banks', AppColors.catBank),
    _Cat('🎓', 'Lecture', AppColors.catLecture),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: _cats.map((c) => _CatChip(c)).toList(),
    );
  }
}

// 3 ── Navigate
class _DashedConnector extends StatelessWidget {
  const _DashedConnector();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 11),
      child: Row(
        children: [
          Column(
            children: List.generate(
              5,
              (_) => Container(
                width: 2,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🚶', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text(
                  '12 min · 900 m',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigateIllustration extends StatelessWidget {
  const _NavigateIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderStrong, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoutePoint(
            color: AppColors.primary,
            label: 'New Moremi Hall',
            sublabel: 'Your location',
            solid: true,
          ),
          const _DashedConnector(),
          _RoutePoint(
            color: AppColors.accent,
            label: 'Faculty of Science',
            sublabel: 'Destination',
            solid: false,
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              _ModeChip(emoji: '🚶', label: 'Walking', active: true),
              SizedBox(width: 8),
              _ModeChip(emoji: '🚗', label: 'Driving', active: false),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  final Color color;
  final String label;
  final String sublabel;
  final bool solid;

  const _RoutePoint({
    required this.color,
    required this.label,
    required this.sublabel,
    required this.solid,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: solid ? color : color.withOpacity(0.15),
              border: solid ? null : Border.all(color: color, width: 2),
            ),
            child: solid
                ? null
                : Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.titleMedium),
              Text(sublabel, style: AppTextStyles.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool active;

  const _ModeChip({
    required this.emoji,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withOpacity(0.14)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? AppColors.primary.withOpacity(0.4)
                : AppColors.borderStrong,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color:
                    active ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 4 ── Nearby
class _NearbyIllustration extends StatelessWidget {
  const _NearbyIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 270,
      height: 270,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ring(260, AppColors.routeWalking, 0.04,
              borderOpacity: 0.14, borderWidth: 1),
          _ring(186, AppColors.routeWalking, 0.07,
              borderOpacity: 0.24, borderWidth: 1.5),
          _ring(112, AppColors.routeWalking, 0.11,
              borderOpacity: 0.4, borderWidth: 1.5),
          // Centre pin
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.routeWalking.withOpacity(0.15),
              border: Border.all(color: AppColors.routeWalking, width: 2),
            ),
            child:
                const Center(child: Text('📍', style: TextStyle(fontSize: 24))),
          ),
          // Orbiting landmark dots
          Positioned(
              top: 24,
              child: _LandmarkDot(
                  emoji: '🏠', color: AppColors.catHostel)),
          Positioned(
              top: 52,
              right: 24,
              child: _LandmarkDot(
                  emoji: '🍽️', color: AppColors.catFood)),
          Positioned(
              bottom: 52,
              right: 20,
              child: _LandmarkDot(
                  emoji: '🏥', color: AppColors.catHealth)),
          Positioned(
              bottom: 24,
              child: _LandmarkDot(
                  emoji: '🏦', color: AppColors.catBank)),
          Positioned(
              bottom: 52,
              left: 20,
              child: _LandmarkDot(
                  emoji: '🏛️', color: AppColors.catFaculty)),
          Positioned(
              top: 52,
              left: 24,
              child: _LandmarkDot(
                  emoji: '🎓', color: AppColors.catLecture)),
        ],
      ),
    );
  }
}

class _LandmarkDot extends StatelessWidget {
  final String emoji;
  final Color color;

  const _LandmarkDot({required this.emoji, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 16))),
    );
  }
}
