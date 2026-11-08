import 'package:flutter/material.dart';

import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../learning/mastery.dart';
import 'theme.dart';

/// 今日一步卡片：一张大图，点一下就去学。
class TodayCard extends StatelessWidget {
  const TodayCard({
    super.key,
    required this.band,
    required this.concept,
    required this.domain,
    required this.tier,
    required this.onTap,
  });

  final AgeBand band;
  final Concept concept;
  final LearningDomain domain;

  /// 这一步当前的档位；没练过为 null。
  final MasteryTier? tier;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final variant = concept.variantFor(band);
    return PaperCard(
      key: Key(concept.id),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                band.showsSubjectNames ? domain.name : '今天',
                style: text.bodySmall,
              ),
              const Spacer(),
              MasteryPill(
                label: tier?.label ?? '可以学',
                color: tier == null ? paperStone : paperOchre,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              width: 152,
              height: 152,
              decoration: BoxDecoration(
                color: domain.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: domain.color.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  variant.glyph ?? domain.glyph,
                  style: const TextStyle(
                    fontSize: 58,
                    height: 1.1,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            variant.topic,
            textAlign: TextAlign.center,
            style: text.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            variant.doing,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: paperInkSoft),
          ),
          const SizedBox(height: 12),
          Text(
            '点一下，就记下这一步',
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
