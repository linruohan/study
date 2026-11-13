import 'age_band.dart';
import 'study_degree.dart';

/// 同一概念在某一档年龄的呈现。
///
/// 这是「认知分级映射表」的一行：概念本身只建一个节点，
/// 幼儿、小学、中学、成人各写自己那一行，不重复造概念。
/// 知识点下的章节（最基础知识单元）。
class KnowledgeChapter {
  const KnowledgeChapter({required this.title, this.content});

  final String title;
  final String? content;

  factory KnowledgeChapter.fromJson(Map<String, Object?> json) {
    return KnowledgeChapter(
      title: json['title'] as String? ?? '',
      content: json['content'] as String?,
    );
  }
}

class ConceptVariant {
  const ConceptVariant({
    required this.topic,
    required this.doing,
    required this.praise,
    required this.check,
    required this.answer,
    this.glyph,
    this.note,
    this.points = const {},
    this.chapters = const {},
  });

  /// 这一档学什么，例如「看见火要远离」。
  final String topic;

  /// 学习者要做的那个具体动作，做完就算这一步完成。
  final String doing;

  /// 做完能说出的「我能……」，不比较、不打分。
  final String praise;

  /// 形成性评价的一句提问，只用来想一想，不计分。
  final String check;

  /// 提问之后的参考回应，可自行对照。
  final String answer;

  /// 大图上的字或符号；留空时用领域图标。
  final String? glyph;

  /// 给本人或监护人的一句说明，可空。
  final String? note;

  /// 按学习程度 id 保存的知识点，来自数据库。
  final Map<String, List<String>> points;

  /// 学习程度 id -> pointPosition(1-based字符串) -> 章节列表。
  final Map<String, Map<String, List<KnowledgeChapter>>> chapters;

  /// 从知识库接口读取一档呈现。
  factory ConceptVariant.fromJson(Map<String, Object?> json) {
    final points = <String, List<String>>{};
    final rawPoints = json['points'];
    if (rawPoints is Map) {
      for (final entry in rawPoints.entries) {
        final value = entry.value;
        if (value is List) {
          points[entry.key.toString()] = [
            for (final item in value)
              if (item is String) item,
          ];
        }
      }
    }
    final chapters = <String, Map<String, List<KnowledgeChapter>>>{};
    final rawChapters = json['chapters'];
    if (rawChapters is Map) {
      for (final degreeEntry in rawChapters.entries) {
        final byPos = <String, List<KnowledgeChapter>>{};
        final posMap = degreeEntry.value;
        if (posMap is Map) {
          for (final posEntry in posMap.entries) {
            final list = posEntry.value;
            if (list is List) {
              byPos[posEntry.key.toString()] = [
                for (final item in list)
                  if (item is Map)
                    KnowledgeChapter.fromJson(Map<String, Object?>.from(item)),
              ];
            }
          }
        }
        chapters[degreeEntry.key.toString()] = byPos;
      }
    }
    return ConceptVariant(
      topic: json['topic'] as String,
      doing: json['doing'] as String,
      praise: json['praise'] as String,
      check: json['check'] as String,
      answer: json['answer'] as String,
      glyph: json['glyph'] as String?,
      note: json['note'] as String?,
      points: points,
      chapters: chapters,
    );
  }

  /// 某个知识点（1-based 位置）下的章节。
  List<KnowledgeChapter> chaptersFor(StudyDegree degree, int pointPosition) {
    return chapters[degree.id]?[pointPosition.toString()] ?? const [];
  }

  /// 某一学习程度下的知识点列表。
  ///
  /// 数据库已给出三档知识点时直接用；个别旧数据缺档时，
  /// 按这句知识的字段派生，保证界面不会空白。
  List<String> pointsFor(StudyDegree degree) {
    final explicit = points[degree.id];
    if (explicit != null && explicit.isNotEmpty) {
      return List.unmodifiable(explicit);
    }
    return switch (degree.id) {
      'beginner' => [topic, doing],
      'familiar' => [check, answer],
      'advanced' => [
          praise,
          if (note != null) note!,
        ],
      _ => const [],
    };
  }
}

/// 原子概念：可学习的最小单元，带前置依赖和跨年龄分级。
class Concept {
  const Concept({
    required this.id,
    required this.domainId,
    required this.depth,
    required this.variants,
    this.prerequisites = const [],
  });

  /// 稳定标识，写进档案和计划。
  final String id;

  /// 所属领域，便于从领域阶梯进入。
  final String domainId;

  /// 领域内的深浅层级，0 最浅。
  final int depth;

  /// 同一概念在各年龄档的呈现；没有写入的档就不出现。
  final Map<AgeBand, ConceptVariant> variants;

  /// 前置概念的 id。前置到达熟练之后才解锁下一项。
  final List<String> prerequisites;

  /// 从知识库接口读取一个概念；未知年龄档的呈现直接跳过。
  factory Concept.fromJson(
    Map<String, Object?> json, {
    required String domainId,
    required Map<String, AgeBand> ageBands,
  }) {
    final variants = <AgeBand, ConceptVariant>{};
    final rawVariants = json['variants'];
    if (rawVariants is Map) {
      for (final entry in rawVariants.entries) {
        final band = ageBands[entry.key.toString()];
        final value = entry.value;
        if (band != null && value is Map) {
          variants[band] = ConceptVariant.fromJson(
            Map<String, Object?>.from(value),
          );
        }
      }
    }

    final prerequisites = <String>[];
    final rawPrerequisites = json['prerequisites'];
    if (rawPrerequisites is List) {
      for (final item in rawPrerequisites) {
        if (item is String) {
          prerequisites.add(item);
        }
      }
    }

    return Concept(
      id: json['id'] as String,
      domainId: domainId,
      depth: json['depth'] as int? ?? 0,
      variants: variants,
      prerequisites: prerequisites,
    );
  }

  /// 这一档是否有可学的内容。
  bool availableIn(AgeBand band) => variants.containsKey(band);

  /// 取这一档的呈现；调用前先用 [availableIn] 判断。
  ConceptVariant variantFor(AgeBand band) => variants[band]!;
}
