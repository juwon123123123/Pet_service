import 'package:flutter/material.dart';

import '../api/models.dart';
import '../theme.dart';
import 'common.dart';

class PetProfileCard extends StatelessWidget {
  final Pet? pet;
  const PetProfileCard({super.key, required this.pet});

  @override
  Widget build(BuildContext context) {
    final p = pet;
    if (p == null) {
      return const AppCard(
        child: Text(
          '아직 등록된 반려동물이 없어요.',
          style: TextStyle(color: AppColors.gray),
        ),
      );
    }
    final emoji = p.species == 'dog' ? '🐶' : '🐱';
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4ED),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.line),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 38)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${p.speciesKo} · ${p.ageKo} · ${p.sexKo}',
                  style: const TextStyle(color: AppColors.gray),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    if (p.ageWeeks < 20)
                      const StatusChip(label: '기초접종 시기')
                    else
                      const StatusChip(label: '정기 케어 단계'),
                    StatusChip(
                      label: p.neutered ? '중성화 완료' : '중성화 미완료',
                      color: p.neutered ? AppColors.green : AppColors.coral,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
