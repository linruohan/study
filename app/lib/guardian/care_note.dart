class CareNote {
  const CareNote(this.body);

  final String body;

  static const choices = [
    CareNote('睡眠比较规律'),
    CareNote('今天会翻身'),
    CareNote('对声音有反应'),
    CareNote('今天有人陪着玩'),
  ];
}
