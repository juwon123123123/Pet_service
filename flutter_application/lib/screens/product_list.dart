import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'product_detail.dart';

final _won = NumberFormat('#,###');

class ProductListScreen extends StatefulWidget {
  final String species; // dog | cat
  const ProductListScreen({super.key, required this.species});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  List<Product>? _products;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _err = null);
    try {
      final list = await api.listProducts(species: widget.species);
      if (!mounted) return;
      setState(() => _products = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_products == null) {
      if (_err != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '상품을 불러오지 못했어요\n$_err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.coral),
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_products!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('등록된 상품이 없어요.', style: TextStyle(color: AppColors.gray)),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.sage,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.68,
        ),
        itemCount: _products!.length,
        itemBuilder: (_, i) => _ProductCard(product: _products![i]),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
          boxShadow: softShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  product.imageUrl.isEmpty
                      ? const ColoredBox(color: AppColors.mint)
                      : Image.network(
                          api.resolveUrl(product.imageUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: AppColors.mint),
                        ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: StatusChip(
                      label: product.category,
                      color: AppColors.charcoal,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_won.format(product.price)}원',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.sage,
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
