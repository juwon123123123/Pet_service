import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 일정 생성/수정 모달.
/// existing == null: 생성, existing != null: 수정.
/// 성공 시 변경된 Event를 pop 결과로 돌려준다.
class EventEditorSheet extends StatefulWidget {
  final int petId;
  final Event? existing;
  final DateTime? initialDate;

  const EventEditorSheet({
    super.key,
    required this.petId,
    this.existing,
    this.initialDate,
  });

  @override
  State<EventEditorSheet> createState() => _EventEditorSheetState();
}

const _categories = <(String, String)>[
  ('vaccine', '예방접종'),
  ('checkup', '병원 상담'),
  ('parasite', '구충'),
  ('grooming', '미용'),
  ('walk', '산책'),
  ('training', '훈련/유치원'),
  ('feeding', '식이'),
  ('socialization', '사회화'),
  ('other', '기타'),
];

class _EventEditorSheetState extends State<EventEditorSheet> {
  late TextEditingController _title;
  late TextEditingController _notes;
  String _category = 'other';
  DateTime _dueDate = DateTime.now();
  bool _recurring = false;
  int? _intervalDays;
  bool _busy = false;
  String? _err;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    if (e != null) {
      _category = e.category;
      _dueDate = e.dueDate;
      _recurring = e.recurring;
      _intervalDays = e.intervalDays;
    } else if (widget.initialDate != null) {
      _dueDate = widget.initialDate!;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      locale: const Locale('ko'),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _err = '일정 이름을 입력해주세요');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
      final Event result;
      if (_isEdit) {
        result = await api.updateEvent(
          widget.existing!.id,
          title: _title.text.trim(),
          category: _category,
          dueDate: _dueDate,
          recurring: _recurring,
          intervalDays: _recurring ? (_intervalDays ?? 7) : null,
          notes: notes ?? '',
        );
      } else {
        result = await api.createEvent(
          widget.petId,
          title: _title.text.trim(),
          category: _category,
          dueDate: _dueDate,
          recurring: _recurring,
          intervalDays: _recurring ? (_intervalDays ?? 7) : null,
          notes: notes,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '저장 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final df = DateFormat('yyyy.MM.dd (E)', 'ko');
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? '일정 수정' : '새 일정',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            AppTextField(
              label: '일정 이름',
              controller: _title,
              hint: '예: 강아지 유치원',
            ),
            const SizedBox(height: 18),
            const Text('카테고리',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories
                  .map((c) => SelectablePill(
                        label: c.$2,
                        selected: _category == c.$1,
                        onTap: () => setState(() => _category = c.$1),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 18),
            const Text('날짜',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    Text(df.format(_dueDate),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SwitchListTile.adaptive(
              value: _recurring,
              onChanged: (v) => setState(() => _recurring = v),
              title: const Text('반복'),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.sage,
            ),
            if (_recurring) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: const [(1, '매일'), (7, '매주'), (30, '매월')]
                    .map((opt) => SelectablePill(
                          label: opt.$2,
                          selected: _intervalDays == opt.$1,
                          onTap: () =>
                              setState(() => _intervalDays = opt.$1),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 18),
            AppTextField(
              label: '메모 (선택)',
              controller: _notes,
              hint: '시간이나 장소 등을 적어두세요',
            ),
            if (_err != null) ...[
              const SizedBox(height: 12),
              Text(_err!,
                  style: const TextStyle(color: AppColors.coral)),
            ],
            const SizedBox(height: 22),
            PrimaryButton(
              label: _isEdit ? '수정 완료' : '일정 추가',
              onPressed: _save,
              loading: _busy,
            ),
          ],
        ),
      ),
    );
  }
}

/// 캘린더 화면에서 시트를 띄우는 헬퍼.
Future<Event?> showEventEditor(
  BuildContext context, {
  required int petId,
  Event? existing,
  DateTime? initialDate,
}) {
  return showModalBottomSheet<Event>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.ivory,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => EventEditorSheet(
      petId: petId,
      existing: existing,
      initialDate: initialDate,
    ),
  );
}
