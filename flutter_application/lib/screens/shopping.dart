import 'package:flutter/material.dart';

import '../theme.dart';
import 'product_list.dart';
import 'recommend_generate.dart';

/// 쇼핑 탭 — 3개 서브탭: 고양이 / 추천 이미지 생성 / 강아지
class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    // 가운데(추천 이미지 생성)를 기본 탭으로
    _tab = TabController(length: 3, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
              child: Row(
                children: [
                  Text(
                    '쇼핑',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontSize: 26),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.line),
                ),
                child: TabBar(
                  controller: _tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  indicatorPadding: const EdgeInsets.all(4),
                  labelColor: AppColors.sage,
                  unselectedLabelColor: AppColors.gray,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800),
                  tabs: const [
                    Tab(text: '🐱 고양이'),
                    Tab(text: '✨ 추천 생성'),
                    Tab(text: '🐶 강아지'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: const [
                  ProductListScreen(species: 'cat'),
                  RecommendGenerateScreen(),
                  ProductListScreen(species: 'dog'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
