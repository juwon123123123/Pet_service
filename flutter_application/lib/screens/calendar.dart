import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/pet_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/schedule_card.dart';
import 'event_editor.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? selectedDay;
  List<Event> events = [];
  bool loading = false;
  String? err;

  @override
  void initState() {
    super.initState();
    selectedDay = DateTime.now();
    petStore.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    petStore.removeListener(_load);
    super.dispose();
  }

  DateTime get _monthStart => DateTime(visibleMonth.year, visibleMonth.month);
  DateTime get _monthEnd =>
      DateTime(visibleMonth.year, visibleMonth.month + 1, 0);

  Future<void> _load() async {
    final pet = petStore.pet;
    if (pet == null) return;
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final list = await api.listEvents(
        pet.id,
        start: _monthStart.subtract(const Duration(days: 7)),
        end: _monthEnd.add(const Duration(days: 7)),
        includeDone: true,
      );
      if (!mounted) return;
      setState(() => events = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _rebuild() async {
    final pet = petStore.pet;
    if (pet == null) return;
    setState(() => loading = true);
    try {
      await api.rebuildCalendar(pet.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('재생성 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openCreate() async {
    final pet = petStore.pet;
    if (pet == null) return;
    final created = await showEventEditor(
      context,
      petId: pet.id,
      initialDate: selectedDay,
    );
    if (created != null) await _load();
  }

  Future<void> _openEdit(Event ev) async {
    final pet = petStore.pet;
    if (pet == null) return;
    final updated = await showEventEditor(
      context,
      petId: pet.id,
      existing: ev,
    );
    if (updated != null) await _load();
  }

  Future<void> _deleteEvent(Event ev) async {
    try {
      await api.deleteEvent(ev.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Event> _eventsOf(DateTime day) =>
      events.where((e) => _isSameDay(e.dueDate, day)).toList();

  @override
  Widget build(BuildContext context) {
    final selected = selectedDay ?? DateTime.now();
    final selectedEvents = _eventsOf(selected);

    // 그리드: 그 달의 첫 주 일요일부터 그리드 시작 (한국 캘린더 관례: 일~토)
    final firstWeekday = _monthStart.weekday % 7; // 일요일=0
    final gridStart = _monthStart.subtract(Duration(days: firstWeekday));
    final totalCells = 42;

    return Scaffold(
      backgroundColor: AppColors.ivory,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: petStore.pet == null ? null : _openCreate,
        backgroundColor: AppColors.sage,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('일정 추가'),
      ),
      body: ScreenShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '케어 캘린더',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 26),
                ),
              ),
              IconButton(
                onPressed: loading ? null : _rebuild,
                tooltip: '캘린더 재생성',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.outlined(
                onPressed: () {
                  setState(() => visibleMonth = DateTime(
                      visibleMonth.year, visibleMonth.month - 1));
                  _load();
                },
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                '${visibleMonth.year}년 ${visibleMonth.month}월',
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800),
              ),
              IconButton.outlined(
                onPressed: () {
                  setState(() => visibleMonth = DateTime(
                      visibleMonth.year, visibleMonth.month + 1));
                  _load();
                },
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              children: [
                const Row(
                  children: [
                    WeekdayLabel('일'),
                    WeekdayLabel('월'),
                    WeekdayLabel('화'),
                    WeekdayLabel('수'),
                    WeekdayLabel('목'),
                    WeekdayLabel('금'),
                    WeekdayLabel('토'),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: totalCells,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 7,
                    crossAxisSpacing: 4,
                  ),
                  itemBuilder: (context, index) {
                    final day = gridStart.add(Duration(days: index));
                    final inMonth = day.month == visibleMonth.month;
                    final isSelected = _isSameDay(day, selected);
                    final dayEvents = _eventsOf(day);
                    return GestureDetector(
                      onTap: inMonth
                          ? () => setState(() => selectedDay = day)
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.coral : null,
                          shape: BoxShape.circle,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                color: !inMonth
                                    ? AppColors.line
                                    : isSelected
                                        ? AppColors.white
                                        : AppColors.charcoal,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 5,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: dayEvents.take(3).map((item) {
                                  return Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 1.2),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.white
                                          : AppColors.sage,
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '${selected.month}월 ${selected.day}일',
            style:
                const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (err != null)
            Text(err!, style: const TextStyle(color: AppColors.coral)),
          if (selectedEvents.isEmpty && err == null)
            const AppCard(
              child: Text(
                '등록된 일정이 없어요.',
                style: TextStyle(color: AppColors.gray, height: 1.4),
              ),
            )
          else
            ...selectedEvents.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ScheduleCard(
                  event: e,
                  onToggleDone: (v) async {
                    try {
                      await api.updateEvent(e.id, done: v);
                      await _load();
                    } catch (err) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('업데이트 실패: $err')),
                      );
                    }
                  },
                  onEdit: () => _openEdit(e),
                  onDelete: () => _deleteEvent(e),
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
      ),
    );
  }
}

class WeekdayLabel extends StatelessWidget {
  final String label;
  const WeekdayLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.gray,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

