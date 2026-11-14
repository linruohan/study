import 'package:flutter_test/flutter_test.dart';

import 'package:study_app/knowledge/concept.dart';
import 'package:study_app/knowledge/study_degree.dart';

void main() {
  final beginner = const StudyDegree(id: 'beginner', label: '入门');
  final familiar = const StudyDegree(id: 'familiar', label: '熟练');
  final advanced = const StudyDegree(id: 'advanced', label: '精通');
  final creative = const StudyDegree(id: 'creative', label: '创造');

  ConceptVariant variantWithLevels(List<String>? familiarLevels) {
    return ConceptVariant.fromJson({
      'topic': '看见火要远离',
      'doing': '远离火源',
      'praise': '我能说出为什么要远离火',
      'check': '火为什么危险？',
      'answer': '火会烫伤人',
      'note': null,
      'points': {
        'beginner': ['看见火要远离', '远离火源'],
        'familiar': ['火为什么危险？', '火会烫伤人'],
        'advanced': ['我能说出为什么要远离火'],
      },
      if (familiarLevels != null)
        'pointLevels': {
          'familiar': familiarLevels,
        },
    });
  }

  test('整包带 pointLevels 时按位置一一对应', () {
    final variant = variantWithLevels(['apply', 'understand']);
    expect(variant.levelsFor(familiar), ['apply', 'understand']);
  });

  test('缺层级时默认「记忆」，缺位时补「记忆」', () {
    expect(variantWithLevels(null).levelsFor(familiar), ['remember', 'remember']);
    // 只给了一层，第二位补「记忆」。
    expect(variantWithLevels(['evaluate']).levelsFor(familiar), ['evaluate', 'remember']);
  });

  test('数据库没给该档知识点时，派生知识点按档位给默认层级', () {
    final variant = variantWithLevels(null);
    // 强制走派生路径：清掉 explicit points。
    final derived = ConceptVariant(
      topic: variant.topic,
      doing: variant.doing,
      praise: variant.praise,
      check: variant.check,
      answer: variant.answer,
      note: '一句说明',
    );
    expect(derived.pointsFor(beginner), ['看见火要远离', '远离火源']);
    expect(derived.levelsFor(beginner), ['remember', 'understand']);
    expect(derived.levelsFor(familiar), ['apply', 'analyze']);
    // note 存在时精通档有两个知识点。
    expect(derived.levelsFor(advanced), ['evaluate', 'create']);
    expect(derived.levelsFor(creative), isEmpty);
  });

  test('认知层级中文标签', () {
    expect(cognitiveLevelLabel('remember'), '记忆');
    expect(cognitiveLevelLabel('create'), '创新');
    expect(cognitiveLevelLabel('unknown'), 'unknown');
  });
}
