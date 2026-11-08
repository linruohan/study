import '../knowledge/age_band.dart';
import '../knowledge/concept.dart';
import '../knowledge/domain.dart';
import '../knowledge/knowledge_graph.dart';
import 'learner_state.dart';
import 'mastery.dart';

/// 阶梯上每一格的状态。
enum LadderStatus { locked, available, attempt, familiar, skilled, mastered }

extension LadderStatusLabel on LadderStatus {
  /// 显示名称；幼儿档不显示学科名，但状态词很短，可以直接念出来。
  String get label {
    return switch (this) {
      LadderStatus.locked => '先学前一项',
      LadderStatus.available => '可以学',
      LadderStatus.attempt => '尝试',
      LadderStatus.familiar => '熟悉',
      LadderStatus.skilled => '熟练',
      LadderStatus.mastered => '掌握',
    };
  }
}

/// 阶梯上的一格：概念、本档呈现、状态和还缺哪些前置。
class LadderEntry {
  const LadderEntry({
    required this.concept,
    required this.variant,
    required this.status,
    this.lockedBy = const [],
  });

  final Concept concept;
  final ConceptVariant variant;
  final LadderStatus status;

  /// 还没到达熟练的前置概念 id；空表示没有阻碍。
  final List<String> lockedBy;

  /// 锁定以外的格子都可以点开，包括复习已经熟练的。
  bool get canOpen => status != LadderStatus.locked;
}

/// 生成某一领域在当前年龄档的阶梯：从浅到深，并标出每格状态。
List<LadderEntry> buildLadder({
  required KnowledgeGraph graph,
  required LearningDomain domain,
  required AgeBand band,
  required LearnerState learner,
}) {
  final ready = learner.readyIds;
  final entries = <LadderEntry>[];
  for (final concept in domain.conceptsFor(band)) {
    final tier = learner.tierOf(concept.id);
    entries.add(
      LadderEntry(
        concept: concept,
        variant: concept.variantFor(band),
        status: _statusFor(concept, tier, ready, graph, band),
        lockedBy: concept.prerequisites.where((id) {
          final prerequisite = graph.conceptById(id);
          if (prerequisite == null || !prerequisite.availableIn(band)) {
            return false;
          }
          return !ready.contains(id);
        }).toList(growable: false),
      ),
    );
  }
  return entries;
}

/// 由档位和前置推出这一格的状态。
LadderStatus _statusFor(
  Concept concept,
  MasteryTier? tier,
  Set<String> ready,
  KnowledgeGraph graph,
  AgeBand band,
) {
  if (tier != null) {
    return switch (tier) {
      MasteryTier.attempt => LadderStatus.attempt,
      MasteryTier.familiar => LadderStatus.familiar,
      MasteryTier.skilled => LadderStatus.skilled,
      MasteryTier.mastered => LadderStatus.mastered,
    };
  }
  if (graph.unlocked(concept, ready, band)) {
    return LadderStatus.available;
  }
  return LadderStatus.locked;
}
