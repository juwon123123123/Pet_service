import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../theme.dart';
import 'common.dart';

final _md = DateFormat('M월 d일', 'ko');

class ScheduleCard extends StatelessWidget {
  final Event event;
  final ValueChanged<bool>? onToggleDone;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ScheduleCard({
    super.key,
    required this.event,
    this.onToggleDone,
    this.onEdit,
    this.onDelete,
  });

  bool get _isUser => event.sourceDocId == 'user';

  void _openDetail(BuildContext context, Color color, String tag) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusChip(label: tag, color: color),
                const Spacer(),
                if (_isUser)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '내가 추가',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.sage),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              event.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${_md.format(event.dueDate)}${event.recurring ? ' · 반복' : ''}',
              style: const TextStyle(color: AppColors.gray, fontSize: 14),
            ),
            if (event.notes != null && event.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                event.notes!,
                style: const TextStyle(
                  color: AppColors.charcoal,
                  height: 1.45,
                  fontSize: 15,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (onEdit != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        onEdit!();
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('수정'),
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
                if (onEdit != null && onDelete != null)
                  const SizedBox(width: 10),
                if (onDelete != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetCtx);
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (dctx) => AlertDialog(
                            title: const Text('일정 삭제'),
                            content: Text('"${event.title}"을(를) 삭제할까요?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dctx, false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(dctx, true),
                                child: const Text(
                                  '삭제',
                                  style: TextStyle(color: AppColors.coral),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) onDelete!();
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('삭제'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.coral,
                        side: const BorderSide(color: AppColors.coral),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const color = AppColors.sage;
    final tag = categoryLabel(event.category);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _openDetail(context, color, tag),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 54,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            decoration: event.done
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color:
                                event.done ? AppColors.gray : AppColors.charcoal,
                          ),
                        ),
                      ),
                      if (_isUser)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.mint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '내가 추가',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.sage,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _md.format(event.dueDate) +
                        (event.recurring ? ' · 반복' : ''),
                    style: const TextStyle(color: AppColors.gray),
                  ),
                  if (event.notes != null && event.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      event.notes!,
                      style: const TextStyle(
                          color: AppColors.gray, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  StatusChip(label: tag, color: color),
                ],
              ),
            ),
            if (onToggleDone != null)
              IconButton(
                onPressed: () => onToggleDone!(!event.done),
                icon: Icon(
                  event.done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: event.done ? AppColors.sage : AppColors.gray,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
