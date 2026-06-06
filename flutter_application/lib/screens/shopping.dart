import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
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
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: PageHeader(
                eyebrow: 'SHOP',
                title: '우리 아이에게\n어울리는 아이템',
                subtitle: '상품을 둘러보고 AI 가상 피팅으로 착용 모습을 미리 확인하세요.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line),
                ),
                child: TabBar(
                  controller: _tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorPadding: const EdgeInsets.all(4),
                  labelColor: AppColors.sage,
                  unselectedLabelColor: AppColors.gray,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  tabs: const [
                    Tab(text: '고양이'),
                    Tab(text: 'AI 피팅'),
                    Tab(text: '강아지'),
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
