/// 学习程度：一个知识按学到的深浅分成三档，每档各有自己的知识点。
enum StudyDegree {
  beginner('入门'),
  familiar('熟悉'),
  advanced('精通');

  const StudyDegree(this.label);

  /// 显示名称。
  final String label;

  /// 由存档里的名称找回程度；未知值返回 null。
  static StudyDegree? fromName(String? name) {
    for (final degree in StudyDegree.values) {
      if (degree.name == name) {
        return degree;
      }
    }
    return null;
  }
}
