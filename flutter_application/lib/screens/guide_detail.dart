import 'package:flutter/material.dart';

import '../api/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class GuideDetailScreen extends StatelessWidget {
  final Guide guide;
  const GuideDetailScreen({super.key, required this.guide});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.ivory,
        elevation: 0,
        title: const Text('AI 케어 가이드',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ScreenShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              color: AppColors.mint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('요약'),
                  const SizedBox(height: 10),
                  Text(guide.summary,
                      style: const TextStyle(fontSize: 15, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ...guide.sections.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionTitle(s.topic),
                        const SizedBox(height: 10),
                        Text(s.advice,
                            style:
                                const TextStyle(fontSize: 14, height: 1.55)),
                        if (s.citations.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: s.citations
                                .map((id) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.ivory,
                                        border:
                                            Border.all(color: AppColors.line),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        id,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.gray),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 8),
            const SectionTitle('전체 출처'),
            const SizedBox(height: 12),
            ...guide.citations.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.docType == 'guideline'
                                ? AppColors.green.withValues(alpha: 0.12)
                                : AppColors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            c.docType == 'guideline' ? 'PDF' : '큐레이션',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: c.docType == 'guideline'
                                  ? AppColors.green
                                  : AppColors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${c.title}${c.label.isNotEmpty ? " · ${c.label}" : ""}',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
