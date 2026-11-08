/// 年龄段：全应用按七档区分学习内容，对应 doc/readme.md 的分龄目录。
///
/// 同一份知识在不同档只换呈现方式，不重复建一套内容。
enum AgeBand {
  /// 3–5 岁：不读文字菜单，点大图、听人说话，学科名不出现。
  toddler(
    id: 'toddler',
    label: '3–5 岁',
    shortLabel: '幼儿',
    howToLearn: '点大图、听人说话。识字、数、情绪和动手混在同一条路线里。',
    showsSubjectNames: false,
  ),

  /// 6–8 岁：开始分科，先具体事物和口算。
  lowerPrimary(
    id: 'lower_primary',
    label: '6–8 岁',
    shortLabel: '小学低段',
    howToLearn: '从这一档起分科。读句子、口算、听说、观察和校园规则。',
    showsSubjectNames: true,
  ),

  /// 9–11 岁：阅读写作、分数与图形、实验与地图。
  upperPrimary(
    id: 'upper_primary',
    label: '9–11 岁',
    shortLabel: '小学高段',
    howToLearn: '读懂一段、写出理由，做分数、面积和一次观察记录。',
    showsSubjectNames: true,
  ),

  /// 12–14 岁：初中建立分科，学概念与出处。
  middleSchool(
    id: 'middle_school',
    label: '12–14 岁',
    shortLabel: '初中',
    howToLearn: '学概念、找出处，用方程和实验说明关系。',
    showsSubjectNames: true,
  ),

  /// 15–17 岁：高中追问原理、条件和证据。
  highSchool(
    id: 'high_school',
    label: '15–17 岁',
    shortLabel: '高中',
    howToLearn: '追问原理与条件，用两则材料互相对照。',
    showsSubjectNames: true,
  ),

  /// 18–20 岁：大学，按方法做完一件可复看的事。
  college(
    id: 'college',
    label: '18–20 岁',
    shortLabel: '大学',
    howToLearn: '读文献、按方法做作业，写下可复算的步骤。',
    showsSubjectNames: true,
  ),

  /// 离开学校以后：不按课表，读生活里的真实文本。
  beyondSchool(
    id: 'beyond_school',
    label: '离开学校以后',
    shortLabel: '社会',
    howToLearn: '读通知、说明和可核对的常识，把学过的东西用在生活里。',
    showsSubjectNames: true,
  );

  const AgeBand({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.howToLearn,
    required this.showsSubjectNames,
  });

  /// 存档里使用的稳定标识，改名不会影响旧档案。
  final String id;

  /// 界面上完整显示的名称。
  final String label;

  /// 窄位置使用的短名称。
  final String shortLabel;

  /// 这一档怎么学，用在选择年龄档的引导里。
  final String howToLearn;

  /// 是否显示学科名。幼儿档只显示图，不显示「语」「数」。
  final bool showsSubjectNames;

  /// 由存档里的 id 找回档位；未知 id 返回 null，避免旧档案让启动失败。
  static AgeBand? fromId(String? id) {
    if (id == null) {
      return null;
    }
    for (final band in AgeBand.values) {
      if (band.id == id) {
        return band;
      }
    }
    return null;
  }
}
