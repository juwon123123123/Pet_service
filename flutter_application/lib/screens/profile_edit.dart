import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/pet_store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 펫 프로필 수정. 등록 화면을 단순화해서 변경 가능한 필드만 노출.
/// - 종(species) 은 변경 불가 (캘린더가 종 기반으로 만들어졌기 때문)
/// - 사진은 즉시 업로드 (PATCH 전에도 반영됨)
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _picker = ImagePicker();

  late final TextEditingController _name;
  late final TextEditingController _breed;
  late final TextEditingController _weight;
  late final TextEditingController _guardian;
  late DateTime _birthDate;
  late String _sex; // 남아 / 여아
  late String _neuter; // 완료 / 미완료 / 모르겠어요

  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _err;
  String? _progressMsg;

  Pet get _pet => petStore.pet!;

  @override
  void initState() {
    super.initState();
    final p = _pet;
    _name = TextEditingController(text: p.name);
    _breed = TextEditingController(text: p.breed ?? '');
    _weight = TextEditingController(
      text: p.weightKg == null ? '' : p.weightKg!.toString(),
    );
    _guardian = TextEditingController(text: petStore.guardianName);
    _birthDate = p.birthDate;
    _sex = p.sex == 'male' ? '남아' : '여아';
    _neuter = p.neutered ? '완료' : '미완료';
  }

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _weight.dispose();
    _guardian.dispose();
    super.dispose();
  }

  String get _birthLabel =>
      '${_birthDate.year}.${_birthDate.month.toString().padLeft(2, '0')}'
      '.${_birthDate.day.toString().padLeft(2, '0')}';

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(now.year - 25),
      lastDate: now,
      helpText: '생년월일을 선택해주세요',
      locale: const Locale('ko'),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
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
      final updated = await api.uploadPetPhoto(_pet.id, picked.path);
      await petStore.setPet(updated);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진 업로드 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _setProgress(String msg) {
    if (!mounted) return;
    setState(() => _progressMsg = msg);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _err = '이름을 입력해주세요');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
      _progressMsg = '프로필 저장 중…';
    });
    try {
      final weight = double.tryParse(_weight.text.trim());
      final updated = await api.updatePet(
        _pet.id,
        name: _name.text.trim(),
        breed: _breed.text.trim(),
        birthDate: _birthDate,
        sex: _sex == '남아' ? 'male' : 'female',
        neutered: _neuter == '완료',
        weightKg: weight,
      );
      await petStore.setPet(updated);
      await petStore.setGuardianName(_guardian.text.trim());

      // 바뀐 정보로 AI 가이드 재생성. 실패해도 저장 자체는 성공으로 처리.
      _setProgress('AI 가이드 다시 만드는 중… (잠시만요)');
      try {
        await api.createGuide(updated.id);
      } catch (e) {
        debugPrint('createGuide 실패(무시): $e');
      }

      // 새 나이/체중 기준으로 캘린더 재생성. 사용자가 추가한 일정은 보존됨.
      _setProgress('맞춤 케어 일정 다시 만드는 중…');
      try {
        await api.rebuildCalendar(updated.id);
      } catch (e) {
        debugPrint('rebuildCalendar 실패(무시): $e');
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '저장 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _progressMsg = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = petStore.pet;
    if (p == null) {
      // 화면 진입 직후 펫이 비어있을 수 없지만 안전망.
      return const Scaffold(body: Center(child: Text('펫이 없습니다.')));
    }
    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(
        backgroundColor: AppColors.ivory,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.charcoal),
        title: const Text(
          '프로필 수정',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: _PhotoThumb(
                        pet: p,
                        uploading: _uploadingPhoto,
                        onTap: _uploadingPhoto ? null : _changePhoto,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        '사진 탭해서 변경',
                        style: const TextStyle(
                            color: AppColors.gray, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: '보호자 이름',
                      controller: _guardian,
                      hint: '예: 유경',
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: '이름',
                      controller: _name,
                      hint: '예: 초코',
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: '품종 (선택)',
                      controller: _breed,
                      hint: '예: 말티즈',
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '생년월일',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _pickBirthDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          border: Border.all(color: AppColors.line),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                color: AppColors.sage, size: 18),
                            const SizedBox(width: 12),
                            Text(_birthLabel,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: '체중(kg, 선택)',
                      controller: _weight,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      hint: '예: 2.1',
                    ),
                    FormSection(
                      title: '성별',
                      child: Wrap(
                        spacing: 10,
                        children: [
                          SelectablePill(
                            label: '남아',
                            selected: _sex == '남아',
                            onTap: () => setState(() => _sex = '남아'),
                          ),
                          SelectablePill(
                            label: '여아',
                            selected: _sex == '여아',
                            onTap: () => setState(() => _sex = '여아'),
                          ),
                        ],
                      ),
                    ),
                    FormSection(
                      title: '중성화 여부',
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: ['완료', '미완료']
                            .map(
                              (item) => SelectablePill(
                                label: item,
                                selected: _neuter == item,
                                onTap: () =>
                                    setState(() => _neuter = item),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 변경 불가 안내
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 18, color: AppColors.sage),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${p.speciesKo}는 변경할 수 없어요. 다른 종이면 새 펫으로 등록해주세요.',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.sage,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_err != null) ...[
                      const SizedBox(height: 14),
                      Text(_err!,
                          style: const TextStyle(
                              color: AppColors.coral,
                              fontWeight: FontWeight.w700)),
                    ],
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 22),
              decoration: const BoxDecoration(
                color: AppColors.ivory,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_progressMsg != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.sage,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _progressMsg!,
                          style: const TextStyle(
                            color: AppColors.sage,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  PrimaryButton(
                    label: '저장',
                    onPressed: _save,
                    loading: _saving,
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

class _PhotoThumb extends StatelessWidget {
  final Pet pet;
  final bool uploading;
  final VoidCallback? onTap;
  const _PhotoThumb(
      {required this.pet, required this.uploading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: 124,
              height: 124,
              color: const Color(0xFFFFF4ED),
              child: pet.photoUrl != null
                  ? Image.network(
                      api.resolveUrl(pet.photoUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: Text(
                          pet.species == 'dog' ? '🐶' : '🐱',
                          style: const TextStyle(fontSize: 56),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        pet.species == 'dog' ? '🐶' : '🐱',
                        style: const TextStyle(fontSize: 56),
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
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.sage,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
