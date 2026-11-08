import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../knowledge/knowledge_graph.dart';
import '../plan/study_plan.dart';
import 'learner_state.dart';
import 'mastery.dart';

/// 一枚徽章：只根据本机记录推算，不联网、不排名。
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.condition,
    required this.earned,
    this.progress,
  });

  /// 稳定标识，界面用 key 标记。
  final String id;

  /// 徽章名称。
  final String title;

  /// 达成条件，未达成时也显示，告诉人下一步做什么。
  final String condition;

  /// 是否已经达成。
  final bool earned;

  /// 当前进度的一句说明，可空。
  final String? progress;
}

/// 领域等级：按学到的最深一格给出「小学到专家级」的称号。
enum StudyLevel {
  primary('小学'),
  middle('初中'),
  high('高中'),
  college('大学'),
  expert('专家级');

  const StudyLevel(this.label);

  /// 显示名称。
  final String label;
}

/// 一个领域在当前档位的等级与进度。
class DomainStanding {
  const DomainStanding({
    required this.domain,
    required this.level,
    required this.ready,
    required this.total,
    required this.mastered,
  });

  /// 对应的领域。
  final LearningDomain domain;

  /// 当前等级；还没把任何一格练到熟练时为 null。
  final StudyLevel? level;

  /// 到熟练的格数。
  final int ready;

  /// 本档总格数。
  final int total;

  /// 到掌握的格数。
  final int mastered;
}

/// 计算当前档位下每个领域的等级，用于「我的」页。
List<DomainStanding> buildStandings({
  required KnowledgeGraph graph,
  required AgeBand band,
  required LearnerState learner,
}) {
  final readyIds = learner.readyIds;
  final list = <DomainStanding>[];
  for (final domain in graph.domainsFor(band)) {
    final concepts = domain.conceptsFor(band);
    final ready = concepts.where((concept) => readyIds.contains(concept.id)).length;
    final mastered = concepts
        .where((concept) => learner.tierOf(concept.id) == MasteryTier.mastered)
        .length;
    list.add(
      DomainStanding(
        domain: domain,
        level: _levelOf(concepts, learner),
        ready: ready,
        total: concepts.length,
        mastered: mastered,
      ),
    );
  }
  return list;
}

/// 等级规则：已练到熟练的最深一格映射到小学/初中/高中/大学；
/// 整个领域都到掌握时是专家级。
StudyLevel? _levelOf(List<Concept> concepts, LearnerState learner) {
  if (concepts.isEmpty) {
    return null;
  }
  final allMastered = concepts.every(
    (concept) => learner.tierOf(concept.id) == MasteryTier.mastered,
  );
  if (allMastered) {
    return StudyLevel.expert;
  }
  var deepest = -1;
  for (final concept in concepts) {
    final tier = learner.tierOf(concept.id);
    if (tier != null && tier.unlocksNext && concept.depth > deepest) {
      deepest = concept.depth;
    }
  }
  if (deepest < 0) {
    return null;
  }
  return switch (deepest) {
    0 => StudyLevel.primary,
    1 => StudyLevel.middle,
    2 => StudyLevel.high,
    _ => StudyLevel.college,
  };
}

/// 生成当前徽章清单；未达成的也一并返回，好让人知道下一步。
List<Achievement> buildAchievements({
  required KnowledgeGraph graph,
  required AgeBand band,
  required LearnerState learner,
  required List<StudyPlan> plans,
}) {
  final domains = graph.domainsFor(band);
  final readyIds = learner.readyIds;
  final practiced = learner.counts.values.where((count) => count > 0).length;
  final familiar = learner.counts.values.any(
    (count) => tierFromCount(count) != MasteryTier.attempt,
  );
  final readyDomains = domains
      .where((domain) =>
          domain.conceptsFor(band).any((concept) => readyIds.contains(concept.id)))
      .length;
  final fullReadyDomain = domains.any((domain) {
    final concepts = domain.conceptsFor(band);
    return concepts.isNotEmpty &&
        concepts.every((concept) => readyIds.contains(concept.id));
  });
  final mastered = learner.counts.values.any(
    (count) => tierFromCount(count) == MasteryTier.mastered,
  );
  final fullMasteredDomain = domains.any((domain) {
    final concepts = domain.conceptsFor(band);
    return concepts.isNotEmpty &&
        concepts.every(
          (concept) => learner.tierOf(concept.id) == MasteryTier.mastered,
        );
  });
  final deepDone =
      plans.any((plan) => plan.depth == PlanDepth.deep && plan.done);
  final briefDone =
      plans.any((plan) => plan.depth == PlanDepth.brief && plan.done);

  return [
    Achievement(
      id: 'first_step',
      title: '第一步',
      condition: '做完任意一步学习',
      earned: practiced > 0,
      progress: '已记录 $practiced 步',
    ),
    Achievement(
      id: 'familiar',
      title: '熟了',
      condition: '把一格练到熟悉',
      earned: familiar,
      progress: familiar ? '有一格已经熟了' : '同一格再练一次',
    ),
    Achievement(
      id: 'three_domains',
      title: '三科点亮',
      condition: '三个领域各有一格到熟练',
      earned: readyDomains >= 3 && domains.length >= 3,
      progress: '$readyDomains/${domains.length} 个领域',
    ),
    Achievement(
      id: 'brief_done',
      title: '说到做到',
      condition: '完成一条简单了解计划',
      earned: briefDone,
      progress: briefDone ? '已完成' : '在计划里点「标记完成」',
    ),
    Achievement(
      id: 'deep_done',
      title: '走到底',
      condition: '完成一条深入学习计划',
      earned: deepDone,
      progress: deepDone ? '已完成' : '深入学习并通过小测',
    ),
    Achievement(
      id: 'domain_ready',
      title: '一门通',
      condition: '某个领域本档全部到熟练',
      earned: fullReadyDomain,
      progress: fullReadyDomain ? '已达成' : '还差几格',
    ),
    Achievement(
      id: 'mastered',
      title: '稳住一格',
      condition: '把一格练到掌握',
      earned: mastered,
      progress: mastered ? '已达成' : '同一格练到第五次',
    ),
    Achievement(
      id: 'expert',
      title: '专家级',
      condition: '某个领域本档全部到掌握',
      earned: fullMasteredDomain,
      progress: fullMasteredDomain ? '已达成' : '全部格数练到掌握',
    ),
  ];
}
