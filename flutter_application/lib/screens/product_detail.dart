import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme.dart';

final _won = NumberFormat('#,###');

/// 풀페이지 상품 상세 — 진짜 쇼핑몰 스타일.
///
/// 두 가지 진입 방식:
///   - 상품 카드 탭: ProductDetailScreen(product: ...) — 데이터 이미 있음
///   - 추천 합성 카드 탭: ProductDetailScreen.fromId(id: ...) — 백엔드에서 fetch
class ProductDetailScreen extends StatefulWidget {
  final Product? product;
  final int? productId;

  /// `product` 가 있으면 그대로 사용. 없고 `productId` 가 있으면 fetch.
  const ProductDetailScreen({super.key, this.product, this.productId})
      : assert(product != null || productId != null);

  /// 추천 합성 카드 등에서 productId만 알 때 사용.
  factory ProductDetailScreen.fromId(int id) =>
      ProductDetailScreen(productId: id);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  String? _err;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    if (_product == null && widget.productId != null) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final p = await api.getProduct(widget.productId!);
      if (!mounted) return;
      setState(() => _product = p);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e');
    }
  }

  void _addToCart() {
    if (_product == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.charcoal,
        content: Text('${_product!.name} 장바구니에 담겼어요 🛒'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _buy() async {
    if (_product == null) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 36,
                    height: 4,
                    child: ColoredBox(color: AppColors.line),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('주문 확인',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              _SummaryRow(label: '상품', value: _product!.name),
              _SummaryRow(
                  label: '결제 금액',
                  value: '${_won.format(_product!.price)}원',
                  emphasize: true),
              _SummaryRow(label: '배송', value: '내일 도착 (무료배송)'),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.charcoal,
                        side: const BorderSide(color: AppColors.line),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sage,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('결제하기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.sage,
          content: Text('🎉 ${_product!.name} 주문이 완료됐어요'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    if (p == null) {
      return Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(backgroundColor: AppColors.white, elevation: 0),
        body: Center(
          child: _err != null
              ? Text('불러오기 실패\n$_err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.coral))
              : const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final speciesLabel = p.species == 'cat'
        ? '고양이'
        : p.species == 'dog'
            ? '강아지'
            : '강아지 / 고양이';

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    backgroundColor: AppColors.white,
                    surfaceTintColor: AppColors.white,
                    elevation: 0,
                    pinned: true,
                    centerTitle: false,
                    title: Text(
                      p.name,
                      style: const TextStyle(
                          color: AppColors.charcoal,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                    iconTheme: const IconThemeData(color: AppColors.charcoal),
                    actions: [
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('공유는 곧 지원돼요')),
                          );
                        },
                        icon: const Icon(Icons.share_outlined),
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: p.imageUrl.isEmpty
                          ? const ColoredBox(color: AppColors.mint)
                          : Image.network(
                              api.resolveUrl(p.imageUrl),
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 22, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$speciesLabel · ${p.category}',
                            style: const TextStyle(
                              color: AppColors.gray,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _won.format(p.price),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.charcoal,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Text(
                                '원',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.charcoal,
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                '무료배송',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.sage,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          if (p.tags.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: p.tags
                                  .map((t) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.mint,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '#$t',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.sage,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: _ThickDivider()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('상품 정보',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 14),
                          _InfoRow(k: '대상', v: speciesLabel),
                          _InfoRow(k: '카테고리', v: p.category),
                          if (p.sizeMinKg != null || p.sizeMaxKg != null)
                            _InfoRow(
                              k: '추천 체중',
                              v: '${p.sizeMinKg?.toStringAsFixed(0) ?? "?"}'
                                  '~${p.sizeMaxKg?.toStringAsFixed(0) ?? "?"} kg',
                            ),
                          _InfoRow(k: '배송', v: '내일 도착 · 무료'),
                          _InfoRow(k: '교환/환불', v: '수령 후 7일 이내 가능'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 하단 sticky bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _addToCart,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.sage,
                        side: const BorderSide(color: AppColors.sage),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '장바구니',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _buy,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sage,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '구매하기',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900),
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

class _ThickDivider extends StatelessWidget {
  const _ThickDivider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 8, color: AppColors.ivory);
}

class _InfoRow extends StatelessWidget {
  final String k;
  final String v;
  const _InfoRow({required this.k, required this.v});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              k,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.gray,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  const _SummaryRow(
      {required this.label, required this.value, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.gray, fontSize: 13)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 17 : 13,
              fontWeight: FontWeight.w900,
              color: emphasize ? AppColors.sage : AppColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}
