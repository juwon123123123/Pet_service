import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'profile_setup.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppLogo(),
              const Spacer(),
              Center(
                child: Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line),
                    boxShadow: softShadow,
                  ),
                  child: const Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 35,
                        right: 38,
                        child: _AnimalCircle(
                          emoji: '🐱',
                          size: 86,
                          color: AppColors.white,
                        ),
                      ),
                      Positioned(
                        left: 34,
                        bottom: 38,
                        child: _AnimalCircle(
                          emoji: '🐶',
                          size: 104,
                          color: Color(0xFFFFF7F1),
                        ),
                      ),
                      Positioned(
                        bottom: 52,
                        right: 48,
                        child: Icon(
                          Icons.favorite_rounded,
                          color: AppColors.coral,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 54),
              Text(
                '처음 키우는 반려생활,\n복잡하지 않게.',
                style: Theme.of(context)
                    .textTheme
                    .headlineLarge
                    ?.copyWith(fontSize: 31, height: 1.22),
              ),
              const SizedBox(height: 18),
              const Text(
                '우리 아이의 나이와 상태에 맞춰\n접종, 중성화 상담, 건강검진 일정을\nAI가 정리해드려요.',
                style: TextStyle(
                  color: AppColors.gray,
                  fontSize: 16,
                  height: 1.55,
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: '시작하기',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PetProfileSetupScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimalCircle extends StatelessWidget {
  final String emoji;
  final double size;
  final Color color;

  const _AnimalCircle({
    required this.emoji,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.line),
      ),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: size * 0.45)),
      ),
    );
  }
}
