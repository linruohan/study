import 'age_band.dart';

/// 同一概念在某一档年龄的呈现。
///
/// 这是「认知分级映射表」的一行：概念本身只建一个节点，
/// 幼儿、小学、中学、成人各写自己那一行，不重复造概念。
class ConceptVariant {
  const ConceptVariant({
    required this.topic,
    required this.doing,
    required this.praise,
    required this.check,
    required this.answer,
    this.glyph,
    this.note,
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

  /// 稳定标识，写进本机档案，用来回看这一步学到哪一档。
  final String id;

  /// 所属领域，便于从领域阶梯进入。
  final String domainId;

  /// 领域内的深浅层级，0 最浅。阶梯按这个值从浅到深排。
  final int depth;

  /// 同一概念在各年龄档的呈现；没有写入的档就不出现。
  final Map<AgeBand, ConceptVariant> variants;

  /// 前置概念的 id。前置到达熟练之后才解锁下一项。
  final List<String> prerequisites;

  /// 这一档是否有可学的内容。
  bool availableIn(AgeBand band) => variants.containsKey(band);

  /// 取这一档的呈现；调用前先用 [availableIn] 判断。
  ConceptVariant variantFor(AgeBand band) => variants[band]!;
}
