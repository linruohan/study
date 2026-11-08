import '../archive/learning_record.dart';

class CareGuidance {
  const CareGuidance({
    required this.what,
    required this.howLong,
    required this.basis,
    required this.alternative,
    required this.reflection,
  });

  final String what;
  final String howLong;
  final String basis;
  final String alternative;
  final String reflection;

  static const footer = '这不是教师、心理咨询师或医生的判断。';

  static const thin = CareGuidance(
    what: '建议：在看护得到的地方活动，并面对着孩子说话。',
    howLong: '大约 5 分钟。',
    basis: '记录还不够。',
    alternative: '也可以在孩子哭时，先查看饥饱、冷暖和困倦。',
    reflection: '没有照护记录，所以用这个年龄的默认一步，不编造特点。',
  );

  static const _unmatched = CareGuidance(
    what: '建议：在看护得到的地方活动，并面对着孩子说话。',
    howLong: '大约 5 分钟。',
    basis: '有一条监护人观察，和现成的提醒对不上，所以不解释。',
    alternative: '也可以在孩子哭时，先查看饥饱、冷暖和困倦。',
    reflection: '这不是原因判定。',
  );

  static const _known = {
    '睡眠比较规律': CareGuidance(
      what: '建议：今晚仍按原来的入睡顺序来。',
      howLong: '大约 10 分钟。',
      basis: '依据是监护人观察「睡眠比较规律」。',
      alternative: '也可以只是陪着，不改顺序。',
      reflection: '这只是照着记下的睡眠习惯说的，不是在判断睡得好不好。',
    ),
    '今天会翻身': CareGuidance(
      what: '建议：在看护得到的地方，让孩子俯卧或仰卧一会儿。',
      howLong: '大约 5 分钟。',
      basis: '依据是监护人观察「今天会翻身」。',
      alternative: '也可以改为抱着对视、说话。',
      reflection: '翻身只说明今天做到了这一下，不拿来比较，也不预测发育。',
    ),
    '对声音有反应': CareGuidance(
      what: '建议：面对着孩子说话，等一下再继续。',
      howLong: '大约 3 分钟。',
      basis: '依据是监护人观察「对声音有反应」。',
      alternative: '也可以改为安静地待在旁边。',
      reflection: '这只是接着记下的这一句，不是听力结论。',
    ),
    '今天有人陪着玩': CareGuidance(
      what: '建议：再陪着玩一会儿，中间叫一叫孩子。',
      howLong: '大约 10 分钟。',
      basis: '依据是监护人观察「今天有人陪着玩」。',
      alternative: '也可以改为在看护得到的地方自己活动。',
      reflection: '只记下有人陪，不给陪的人打分。',
    ),
  };

  static CareGuidance fromRecords(Iterable<LearningRecord> records) {
    final notes = records.where((record) => record.source == '监护人观察').toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    if (notes.isEmpty) {
      return thin;
    }
    return _known[notes.last.body] ?? _unmatched;
  }
}
