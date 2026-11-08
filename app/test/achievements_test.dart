import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/knowledge/age_band.dart';
import 'package:study_app/knowledge/knowledge_graph.dart';
import 'package:study_app/learning/achievements.dart';
import 'package:study_app/learning/learner_state.dart';
import 'package:study_app/plan/study_plan.dart';

void main() {
  const graph = KnowledgeGraph.defaults;

  test('没有记录时等级为空，徽章都未达成', () {
    final learner = LearnerState({});
    final standings = buildStandings(
      graph: graph,
      band: AgeBand.toddler,
      learner: learner,
    );
    expect(standings.every((standing) => standing.level == null), isTrue);

    final badges = buildAchievements(
      graph: graph,
      band: AgeBand.toddler,
      learner: learner,
      plans: const [],
    );
    expect(badges.any((badge) => badge.earned), isFalse);
  });

  test('练到熟练会给小学等级和第一步徽章', () {
    final learner = LearnerState({'zi_ri': 4});
    final standings = buildStandings(
      graph: graph,
      band: AgeBand.toddler,
      learner: learner,
    );
    final language = standings.firstWhere((standing) => standing.domain.id == 'language');
    expect(language.ready, 1);
    expect(language.level, StudyLevel.primary);

    final badges = buildAchievements(
      graph: graph,
      band: AgeBand.toddler,
      learner: learner,
      plans: const [],
    );
    expect(badges.firstWhere((badge) => badge.id == 'first_step').earned, isTrue);
    expect(badges.firstWhere((badge) => badge.id == 'mastered').earned, isFalse);
  });

  test('领域全部掌握是专家级，完成深入学习计划给徽章', () {
    final learner = LearnerState({'zi_ri': 5});
    final standings = buildStandings(
      graph: graph,
      band: AgeBand.toddler,
      learner: learner,
    );
    final language = standings.firstWhere((standing) => standing.domain.id == 'language');
    expect(language.level, StudyLevel.expert);

    final badges = buildAchievements(
      graph: graph,
      band: AgeBand.toddler,
      learner: learner,
      plans: [
        StudyPlan(
          id: 'p1',
          domainId: 'language',
          depth: PlanDepth.deep,
          startAt: DateTime(2026, 1, 1),
          done: true,
        ),
      ],
    );
    expect(badges.firstWhere((badge) => badge.id == 'expert').earned, isTrue);
    expect(badges.firstWhere((badge) => badge.id == 'deep_done').earned, isTrue);
  });
}
