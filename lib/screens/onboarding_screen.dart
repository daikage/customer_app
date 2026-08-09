import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_theme.dart';
import '../main.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Move Anything,\nAnywhere.',
      'description': 'From single rides to heavy haulage and interstate trips, we\'ve got you covered.',
      'icon': Icons.directions_car,
      'color': AppColors.singleRide,
    },
    {
      'title': 'Dispatch &\nDeliveries.',
      'description': 'Send packages securely across town with our real-time tracking dispatch service.',
      'icon': Icons.inventory_2,
      'color': AppColors.dispatch,
    },
    {
      'title': 'Premium\nExperience.',
      'description': 'Enjoy safe, reliable rides with our network of professional and verified drivers.',
      'icon': Icons.star,
      'color': AppColors.accent,
    },
  ];

  void _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (!mounted) return;
    ref.read(onboardingStateProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final page = _pages[index];
              return Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        height: 250,
                        width: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (page['color'] as Color).withOpacity(0.1),
                        ),
                        child: Icon(
                          page['icon'],
                          size: 100,
                          color: page['color'],
                        ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                         .scaleXY(begin: 0.9, end: 1.1, duration: 1500.ms, curve: Curves.easeInOut),
                      ),
                    ).animate().fade(duration: 600.ms).slideY(begin: 0.1, end: 0),
                    
                    const SizedBox(height: 60),
                    
                    Text(
                      page['title'],
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ).animate().fade(delay: 200.ms, duration: 600.ms).slideX(begin: -0.1, end: 0),
                    
                    const SizedBox(height: 20),
                    
                    Text(
                      page['description'],
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ).animate().fade(delay: 400.ms, duration: 600.ms).slideX(begin: -0.1, end: 0),
                  ],
                ),
              );
            },
          ),
          
          Positioned(
            bottom: 50,
            left: 40,
            right: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 8),
                      height: 8,
                      width: _currentIndex == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentIndex == index
                            ? AppColors.primary
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                
                GestureDetector(
                  onTap: () {
                    if (_currentIndex == _pages.length - 1) {
                      _completeOnboarding();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.ease,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: AppShadows.glow(AppColors.primary),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentIndex == _pages.length - 1 ? 'Get Started' : 'Next',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ).animate().scale(delay: 600.ms, duration: 400.ms, curve: Curves.easeOutBack),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
