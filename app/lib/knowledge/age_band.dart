/// 年龄段：全应用按七档区分学习内容。
///
/// 名称、说明与是否显示学科名都来自数据库，客户端不再内置这些文案。
/// 这里的对象只是接口数据的内存形态，id 是稳定标识。
class AgeBand {
  const AgeBand({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.howToLearn,
    required this.showsSubjectNames,
  });

  /// 稳定标识，存档和接口里都用它。
  final String id;

  /// 界面上完整显示的名称。
  final String label;

  /// 窄位置使用的短名称。
  final String shortLabel;

  /// 这一档怎么学，用在选择年龄档的引导里。
  final String howToLearn;

  /// 是否显示学科名。幼儿档只显示图，不显示「语」「数」。
  final bool showsSubjectNames;

  /// 从知识库接口读取一档年龄。
  factory AgeBand.fromJson(Map<String, Object?> json) {
    return AgeBand(
      id: json['id'] as String,
      label: json['label'] as String,
      shortLabel: json['shortLabel'] as String,
      howToLearn: json['howToLearn'] as String,
      showsSubjectNames: json['showsSubjectNames'] as bool? ?? true,
    );
  }
}
