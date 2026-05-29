import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/pet_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'main_tab.dart';

/// 펫 등록 화면.
/// - 종/성별/중성화는 라벨 그대로, 백엔드 enum으로 매핑해서 전송
/// - 생년월일은 DatePicker로 받음(자유 텍스트 ❌ - 백엔드는 ISO date 요구)
/// - "추정 나이"는 보조용. 실제 birth_date가 있으면 그걸 우선.
class PetProfileSetupScreen extends StatefulWidget {
  const PetProfileSetupScreen({super.key});

  @override
  State<PetProfileSetupScreen> createState() => _PetProfileSetupScreenState();
}

class _PetProfileSetupScreenState extends State<PetProfileSetupScreen> {
  String type = '강아지';
  String gender = '남아';
  String neuter = '미완료';
  String vaccine = '일부 완료';
  final environments = <String>{'실내 생활', '입양한 지 얼마 안 됨'};

  final guardianController = TextEditingController();
  final nameController = TextEditingController();
  final breedController = TextEditingController();
  final weightController = TextEditingController();
  DateTime birthDate = DateTime.now().subtract(const Duration(days: 70));

  final _picker = ImagePicker();
  String? _pickedPhotoPath; // 로컬 파일 경로. 등록 후 업로드.

  bool submitting = false;
  String? errorMsg;
  String? progressMsg;

  @override
  void dispose() {
    guardianController.dispose();
    nameController.dispose();
    breedController.dispose();
    weightController.dispose();
    super.dispose();
  }

  String get _birthLabel {
    return '${birthDate.year}.${birthDate.month.toString().padLeft(2, '0')}.${birthDate.day.toString().padLeft(2, '0')}';
  }

  String get _ageHint {
    final days = DateTime.now().difference(birthDate).inDays;
    if (days < 0) return '';
    final weeks = days ~/ 7;
    if (weeks < 16) return '생후 $weeks주';
    final months = (days / 30.4375).floor();
    return '생후 $months개월';
  }

  Future<void> _pickPhoto() async {
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
    setState(() => _pickedPhotoPath = picked.path);
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: birthDate,
      firstDate: DateTime(now.year - 25),
      lastDate: now,
      helpText: '생년월일을 선택해주세요',
      locale: const Locale('ko'),
    );
    if (picked != null) setState(() => birthDate = picked);
  }

  void _setProgress(String msg) {
    if (!mounted) return;
    setState(() => progressMsg = msg);
  }

  Future<void> _submit() async {
    if (nameController.text.trim().isEmpty) {
      setState(() => errorMsg = '이름을 입력해주세요');
      return;
    }
    setState(() {
      submitting = true;
      errorMsg = null;
      progressMsg = '프로필 저장 중…';
    });
    try {
      final weight = double.tryParse(weightController.text.trim());
      final body = PetCreate(
        name: nameController.text.trim(),
        species: type == '강아지' ? 'dog' : 'cat',
        breed: breedController.text.trim().isEmpty
            ? null
            : breedController.text.trim(),
        birthDate: birthDate,
        sex: gender == '남아' ? 'male' : 'female',
        neutered: neuter == '완료',
        weightKg: weight,
      );
      var pet = await api.createPet(body);
      // 사진 골라뒀으면 등록 직후 업로드 (실패해도 펫 등록은 유지).
      if (_pickedPhotoPath != null) {
        _setProgress('사진 업로드 중…');
        try {
          pet = await api.uploadPetPhoto(pet.id, _pickedPhotoPath!);
        } catch (e) {
          debugPrint('펫 사진 업로드 실패(무시): $e');
        }
      }
      await petStore.setPet(pet);
      if (guardianController.text.trim().isNotEmpty) {
        await petStore.setGuardianName(guardianController.text.trim());
      }
      // AI 가이드 생성 (Gemini RAG). 실패해도 진입은 허용.
      _setProgress('AI 가이드 만드는 중… (조금만 기다려주세요)');
      try {
        await api.createGuide(pet.id);
      } catch (e) {
        debugPrint('createGuide 실패(무시): $e');
      }
      // 캘린더 자동 생성. 실패해도 진입은 허용.
      _setProgress('맞춤 케어 일정 만드는 중…');
      try {
        await api.rebuildCalendar(pet.id);
      } catch (e) {
        debugPrint('rebuildCalendar 실패(무시): $e');
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainTabScreen()),
        (_) => false,
      );
    } catch (e) {
      setState(() => errorMsg = '등록 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          submitting = false;
          progressMsg = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.ivory,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.charcoal),
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
                    Text(
                      '우리 아이 정보를 알려주세요',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontSize: 25),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '입력한 정보를 바탕으로 맞춤 케어 일정을 만들어드릴게요.',
                      style: TextStyle(color: AppColors.gray, fontSize: 15),
                    ),
                    const SizedBox(height: 24),
                    Center(child: _PhotoPickerThumb(
                      path: _pickedPhotoPath,
                      onPick: _pickPhoto,
                    )),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: '보호자 이름 (선택)',
                      controller: guardianController,
                      hint: '예: 유경',
                    ),
                    FormSection(
                      title: '반려동물 종류',
                      child: Wrap(
                        spacing: 10,
                        children: [
                          SelectablePill(
                            label: '강아지',
                            selected: type == '강아지',
                            onTap: () => setState(() => type = '강아지'),
                          ),
                          SelectablePill(
                            label: '고양이',
                            selected: type == '고양이',
                            onTap: () => setState(() => type = '고양이'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: '이름',
                      controller: nameController,
                      hint: '예: 초코',
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: '품종 (선택)',
                      controller: breedController,
                      hint: '예: 말티즈',
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '생년월일',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15),
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
                            Text(
                              _birthLabel,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _ageHint,
                              style: const TextStyle(
                                  color: AppColors.gray, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: '체중(kg, 선택)',
                      controller: weightController,
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
                            selected: gender == '남아',
                            onTap: () => setState(() => gender = '남아'),
                          ),
                          SelectablePill(
                            label: '여아',
                            selected: gender == '여아',
                            onTap: () => setState(() => gender = '여아'),
                          ),
                        ],
                      ),
                    ),
                    FormSection(
                      title: '중성화 여부',
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: ['완료', '미완료', '모르겠어요']
                            .map(
                              (item) => SelectablePill(
                                label: item,
                                selected: neuter == item,
                                onTap: () => setState(() => neuter = item),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    FormSection(
                      title: '접종 이력 (메모)',
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: ['아직 안 했어요', '일부 완료', '모두 완료', '잘 모르겠어요']
                            .map(
                              (item) => SelectablePill(
                                label: item,
                                selected: vaccine == item,
                                onTap: () =>
                                    setState(() => vaccine = item),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    FormSection(
                      title: '생활환경',
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          '실내 생활',
                          '산책 자주 함',
                          '다견/다묘 가정',
                          '입양한 지 얼마 안 됨'
                        ]
                            .map(
                              (item) => SelectablePill(
                                label: item,
                                selected: environments.contains(item),
                                onTap: () {
                                  setState(() {
                                    environments.contains(item)
                                        ? environments.remove(item)
                                        : environments.add(item);
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        errorMsg!,
                        style: const TextStyle(
                            color: AppColors.coral,
                            fontWeight: FontWeight.w700),
                      ),
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
                  if (progressMsg != null) ...[
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
                          progressMsg!,
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
                    label: '맞춤 케어 일정 만들기',
                    onPressed: _submit,
                    loading: submitting,
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

class _PhotoPickerThumb extends StatelessWidget {
  final String? path;
  final VoidCallback onPick;
  const _PhotoPickerThumb({required this.path, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPick,
          child: Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.line, width: 1.4),
              borderRadius: BorderRadius.circular(28),
            ),
            clipBehavior: Clip.antiAlias,
            child: path == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            size: 28, color: AppColors.sage),
                        SizedBox(height: 6),
                        Text('우리 아이 사진',
                            style: TextStyle(
                                color: AppColors.gray, fontSize: 12)),
                      ],
                    ),
                  )
                : Image.file(File(path!), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          path == null ? '사진을 추가해주세요 (선택)' : '탭해서 다시 고르기',
          style: const TextStyle(color: AppColors.gray, fontSize: 12),
        ),
      ],
    );
  }
}
