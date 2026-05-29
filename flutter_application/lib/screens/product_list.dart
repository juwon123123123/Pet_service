import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme.dart';
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
            child: Text('상품을 불러오지 못했어요\n$_err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.coral)),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_products!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('등록된 상품이 없어요.',
              style: TextStyle(color: AppColors.gray)),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.sage,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
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
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: product),
        ));
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
          boxShadow: softShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: product.imageUrl.isEmpty
                  ? const ColoredBox(color: AppColors.mint)
                  : Image.network(
                      api.resolveUrl(product.imageUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: AppColors.mint),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
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

