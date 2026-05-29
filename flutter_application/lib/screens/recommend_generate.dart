import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/pet_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'product_detail.dart';

/// 추천 이미지 생성.
/// - 소스 사진 선택: 등록한 펫 사진 / 새로 업로드
/// - 시작 누르면 백엔드가 5개 상품에 대해 합성 job 만들고 백그라운드 실행
/// - 이 화면은 GET /generations 로 폴링하며 결과 누적 표시
class RecommendGenerateScreen extends StatefulWidget {
  const RecommendGenerateScreen({super.key});

  @override
  State<RecommendGenerateScreen> createState() =>
      _RecommendGenerateScreenState();
}

class _RecommendGenerateScreenState extends State<RecommendGenerateScreen>
    with AutomaticKeepAliveClientMixin {
  final _picker = ImagePicker();
  List<Generation> _all = [];
  bool _starting = false;
  Timer? _poll;
  String? _err;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    petStore.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    petStore.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final pet = petStore.pet;
    if (pet == null) {
      setState(() => _all = []);
      return;
    }
    try {
      final list = await api.listGenerations(pet.id);
      if (!mounted) return;
      setState(() {
        _all = list;
        _err = null;
      });
      _ensurePolling();
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e');
    }
  }

  void _ensurePolling() {
    // pending 이 하나라도 있으면 4초마다 갱신, 모두 끝나면 폴링 중단.
    final anyPending = _all.any((g) => g.isPending);
    if (anyPending) {
      _poll ??= Timer.periodic(const Duration(seconds: 4), (_) => _load());
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  Future<void> _start({required bool useRegistered}) async {
    final pet = petStore.pet;
    if (pet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 펫 정보 탭에서 등록해주세요.')),
      );
      return;
    }
    String? tempPath;
    if (!useRegistered) {
      final source = await _pickImageSource();
      if (source == null) return;
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
      if (picked == null) return;
      setState(() => _starting = true);
      try {
        tempPath = await api.uploadTempPhoto(picked.path);
      } catch (e) {
        if (!mounted) return;
        setState(() => _starting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사진 업로드 실패: $e')),
        );
        return;
      }
    } else {
      if (pet.photoUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('등록된 사진이 없어요. 새 사진을 업로드해주세요.')),
        );
        return;
      }
      setState(() => _starting = true);
    }
    try {
      await api.startGenerations(
        petId: pet.id,
        useRegistered: useRegistered,
        tempPhotoPath: tempPath,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('생성 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<ImageSource?> _pickImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.sage),
              title: const Text('카메라로 찍기'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.sage),
              title: const Text('앨범에서 고르기'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pet = petStore.pet;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.sage,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AppCard(
            color: AppColors.mint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('AI 옷 코디 추천'),
                const SizedBox(height: 6),
                Text(
                  pet == null
                      ? '먼저 펫을 등록해주세요.'
                      : '${pet.name}에게 어울릴 옷 5개를 추천하고, 입은 모습을 합성해드려요.',
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.charcoal, height: 1.5),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _starting || pet == null
                            ? null
                            : () => _start(useRegistered: true),
                        icon: const Icon(Icons.pets_rounded, size: 18),
                        label: const Text('등록 사진으로'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.sage,
                          side: const BorderSide(color: AppColors.sage),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _starting || pet == null
                            ? null
                            : () => _start(useRegistered: false),
                        icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                        label: const Text('새 사진 업로드'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.sage,
                          foregroundColor: AppColors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_starting) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(color: AppColors.sage),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_err != null)
            Text(_err!,
                style: const TextStyle(color: AppColors.coral, fontSize: 13)),
          if (_all.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  '아직 생성된 합성 이미지가 없어요.\n위 버튼을 눌러 시작해보세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.gray, height: 1.5),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemCount: _all.length,
              itemBuilder: (_, i) => _GenerationCard(
                gen: _all[i],
                onDelete: () async {
                  try {
                    await api.deleteGeneration(_all[i].id);
                    await _load();
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('삭제 실패: $e')),
                    );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _GenerationCard extends StatelessWidget {
  final Generation gen;
  final VoidCallback onDelete;
  const _GenerationCard({required this.gen, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (gen.isDone && gen.resultUrl != null) {
      image = Image.network(
        api.resolveUrl(gen.resultUrl!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.mint),
      );
    } else if (gen.isPending) {
      image = const ColoredBox(
        color: AppColors.mint,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.sage),
              ),
              SizedBox(height: 8),
              Text('생성 중…',
                  style: TextStyle(color: AppColors.sage, fontSize: 12)),
            ],
          ),
        ),
      );
    } else {
      // failed
      image = ColoredBox(
        color: AppColors.coral.withValues(alpha: 0.12),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text('실패\n다시 시도해보세요',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.coral, fontSize: 12)),
          ),
        ),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      // 탭: 합성된 옷의 상품 상세 페이지로 이동.
      // 롱프레스: 생성 이미지 전체보기.
      onTap: gen.isDone
          ? () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProductDetailScreen.fromId(gen.productId),
              ));
            }
          : null,
      onLongPress: gen.isDone
          ? () {
              showDialog(
                context: context,
                builder: (_) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(api.resolveUrl(gen.resultUrl!)),
                  ),
                ),
              );
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
          boxShadow: softShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(child: image),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white70,
                  minimumSize: const Size(30, 30),
                  padding: EdgeInsets.zero,
                ),
                iconSize: 16,
                onPressed: onDelete,
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.gray),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
                child: Text(
                  '#${gen.productId}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
