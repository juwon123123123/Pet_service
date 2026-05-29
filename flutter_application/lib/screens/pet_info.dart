import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/pet_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'guide_detail.dart';
import 'onboarding.dart';
import 'profile_edit.dart';

final _md = DateFormat('M월 d일 (E)', 'ko');

/// 펫 정보 탭 — 기존 Home + MyPet 흡수.
/// 위에서부터: 인사 + 펫 카드 + 사진 변경 + 이번 주 일정 + AI 가이드 + 메뉴 + 삭제.
class PetInfoScreen extends StatefulWidget {
  const PetInfoScreen({super.key});

  @override
  State<PetInfoScreen> createState() => _PetInfoScreenState();
}

class _PetInfoScreenState extends State<PetInfoScreen> {
  List<Event>? _upcoming;
  Guide? _guide;
  bool _loadingGuide = false;
  bool _uploadingPhoto = false;
  String? _err;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    petStore.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    petStore.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final pet = petStore.pet;
    if (pet == null) return;
    setState(() => _err = null);
    try {
      // 펫 자체도 다시 가져와서 photoUrl 등이 최신화되도록.
      await petStore.refresh();
      final results = await Future.wait([
        api.upcoming(pet.id, days: 7),
        api.latestGuide(pet.id),
      ]);
      if (!mounted) return;
      setState(() {
        _upcoming = results[0] as List<Event>;
        _guide = results[1] as Guide?;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e');
    }
  }

  Future<void> _generateGuide() async {
    final pet = petStore.pet;
    if (pet == null) return;
    setState(() => _loadingGuide = true);
    try {
      final g = await api.createGuide(pet.id);
      if (!mounted) return;
      setState(() => _guide = g);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('가이드 생성 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingGuide = false);
    }
  }

  Future<void> _changePhoto() async {
    final pet = petStore.pet;
    if (pet == null) return;
    final source = await _pickImageSource();
    if (source == null) return;
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final updated = await api.uploadPetPhoto(pet.id, picked.path);
      await petStore.setPet(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진 업로드 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
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

  Future<void> _confirmDelete() async {
    final pet = petStore.pet;
    if (pet == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('펫 삭제'),
        content: Text('${pet.name}의 모든 데이터(일정, 가이드, 합성 이미지)를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제',
                style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await api.deletePet(pet.id);
      await petStore.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = petStore.pet;
    final guardian = petStore.guardianName;
    return ScreenShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeaderRow(
            title: guardian.isEmpty ? '안녕하세요' : '안녕하세요, $guardian님',
            subtitle: pet == null
                ? '먼저 우리 아이를 등록해주세요.'
                : '${pet.name}의 정보와 일정을 확인해보세요.',
            action: IconButton.filledTonal(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(height: 22),
          _PhotoPetCard(
            pet: pet,
            uploading: _uploadingPhoto,
            onChangePhoto: _changePhoto,
          ),
          if (_err != null) ...[
            const SizedBox(height: 12),
            Text(_err!,
                style: const TextStyle(color: AppColors.coral, fontSize: 13)),
          ],
          const SizedBox(height: 18),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('이번 주 케어'),
                const SizedBox(height: 14),
                if (_upcoming == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_upcoming!.isEmpty)
                  const Text(
                    '이번 주에 예정된 일정이 없어요. 가볍게 컨디션만 확인해주세요.',
                    style: TextStyle(color: AppColors.gray),
                  )
                else
                  ..._upcoming!.take(3).map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 7),
                                decoration: BoxDecoration(
                                  color: AppColors.sage,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${_md.format(e.dueDate)} · ${e.title}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            color: AppColors.mint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: SectionTitle('AI가 추천하는 케어')),
                    if (_loadingGuide)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_guide == null)
                  const Text(
                    'AI 가이드를 아직 만들지 않았어요.\n아래 버튼을 눌러 우리 아이 상태에 맞춘 추천을 받아보세요.',
                    style: TextStyle(fontSize: 15, height: 1.5),
                  )
                else
                  Text(_guide!.summary,
                      style: const TextStyle(fontSize: 15, height: 1.5)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: pet == null ? null : _generateGuide,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.sage,
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(_guide == null ? 'AI 가이드 만들기' : '다시 생성'),
                    ),
                    const SizedBox(width: 14),
                    if (_guide != null)
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                GuideDetailScreen(guide: _guide!),
                          ));
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.sage,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('자세히 보기'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // 메뉴 / 삭제 영역
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MenuRow(
                  icon: Icons.edit_outlined,
                  title: '프로필 수정',
                  onTap: () async {
                    final saved = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const ProfileEditScreen(),
                      ),
                    );
                    if (saved == true) await _load();
                  },
                ),
                _MenuRow(
                  icon: Icons.notifications_active_outlined,
                  title: '알림 설정',
                  onTap: null,
                ),
                _MenuRow(
                  icon: Icons.delete_outline_rounded,
                  title: '펫 삭제',
                  onTap: _confirmDelete,
                  destructive: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _PhotoPetCard extends StatelessWidget {
  final Pet? pet;
  final bool uploading;
  final VoidCallback onChangePhoto;

  const _PhotoPetCard({
    required this.pet,
    required this.uploading,
    required this.onChangePhoto,
  });

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
    return AppCard(
      child: Row(
        children: [
          GestureDetector(
            onTap: uploading ? null : onChangePhoto,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 84,
                    height: 84,
                    color: const Color(0xFFFFF4ED),
                    child: p.photoUrl != null
                        ? Image.network(
                            api.resolveUrl(p.photoUrl!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                              child: Text(
                                p.species == 'dog' ? '🐶' : '🐱',
                                style: const TextStyle(fontSize: 42),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              p.species == 'dog' ? '🐶' : '🐱',
                              style: const TextStyle(fontSize: 42),
                            ),
                          ),
                  ),
                ),
                if (uploading)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x66000000),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.sage,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
              ],
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
                    StatusChip(
                      label: p.ageWeeks < 20 ? '기초접종 시기' : '정기 케어 단계',
                    ),
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

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool destructive;

  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.coral : AppColors.sage;
    return InkWell(
      onTap: onTap ??
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('다음 업데이트에서 지원돼요.')),
            );
          },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: destructive
                      ? AppColors.coral
                      : AppColors.charcoal,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.gray),
          ],
        ),
      ),
    );
  }
}
