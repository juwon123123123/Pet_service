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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppLogo(),
              const Spacer(),
              const _HeroDevice(),
              const SizedBox(height: 44),
              Text(
                '반려생활을\n한눈에, 더 가볍게.',
                style: Theme.of(context)
                    .textTheme
                    .headlineLarge
                    ?.copyWith(fontSize: 34, height: 1.12),
              ),
              const SizedBox(height: 18),
              const Text(
                '우리 아이의 프로필을 기준으로\n케어 일정과 AI 가이드를 깔끔하게 정리해요.',
                style: TextStyle(
                  color: AppColors.gray,
                  fontSize: 16,
                  height: 1.5,
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

class _HeroDevice extends StatelessWidget {
  const _HeroDevice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.charcoal,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 40,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.pets_rounded,
                      color: AppColors.sage,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '오늘의 케어',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '3개 일정',
                          style: TextStyle(
                            color: AppColors.gray,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _HeroTask(label: '기초 접종 체크', done: true),
              const _HeroTask(label: '몸무게 기록', done: true),
              const _HeroTask(label: 'AI 케어 가이드', done: false),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroTask extends StatelessWidget {
  final String label;
  final bool done;

  const _HeroTask({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: done ? AppColors.green : AppColors.gray,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
