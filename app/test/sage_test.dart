import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/data/sage_api.dart';
import 'package:study_app/knowledge/sage_credit.dart';

void main() {
  test('SageContribution 从接口 JSON 解析', () {
    final json = {
      'id': 'c1',
      'kind': 'knowledge',
      'domainId': 'life',
      'ageBandId': 'beyond_school',
      'degreeId': 'beginner',
      'conceptId': 'sage_abc12345',
      'position': null,
      'topic': '垃圾分类三句话',
      'doing': '把一件垃圾按可回收、厨余和其他分对',
      'note': '拿不准时先归入其他垃圾。',
      'status': 'approved',
      'reviewedAt': '2026-11-12T14:30:39.294Z',
      'createdAt': '2026-11-12T14:30:39.294Z',
    };
    final contribution = SageContribution.fromJson(json);
    expect(contribution.id, 'c1');
    expect(contribution.kind, 'knowledge');
    expect(contribution.conceptId, 'sage_abc12345');
    expect(contribution.position, isNull);
    expect(contribution.topic, '垃圾分类三句话');
    expect(contribution.status, 'approved');
  });

  test('SageContribution 缺字段时容错，不抛异常', () {
    final contribution = SageContribution.fromJson({
      'id': 'c2',
      'kind': 'point',
      'domainId': null,
      'ageBandId': null,
      'degreeId': null,
      'conceptId': null,
      'position': 3,
      'topic': '玻璃瓶先冲洗再丢弃',
      'doing': null,
      'note': null,
      'status': 'approved',
      'reviewedAt': null,
      'createdAt': '2026-11-12T14:31:27.196Z',
    });
    expect(contribution.position, 3);
    expect(contribution.doing, isNull);
  });

  test('SageCredits 从接口 JSON 解析，并给出概念与知识点的创建者', () {
    final credits = SageCredits.fromJson({
      'knowledge': {'sage_76e1221d': 'YG'},
      'points': {'sage_76e1221d:beyond_school:beginner:3': 'YG'},
    });
    expect(credits.creatorOfConcept('sage_76e1221d'), 'YG');
    expect(credits.creatorOfConcept('other'), '');
    expect(
      credits.creatorOfPoint('sage_76e1221d:beyond_school:beginner:3'),
      'YG',
    );
    expect(credits.creatorOfPoint('unknown'), '');
  });

  test('SageCredits 为空或缺失时返回空归属', () {
    const empty = SageCredits(knowledge: {}, points: {});
    expect(empty.creatorOfConcept('x'), '');
    expect(empty.creatorOfPoint('x'), '');

    final fromNull = SageCredits.fromJson(null);
    expect(fromNull.knowledge, isEmpty);
    expect(fromNull.points, isEmpty);
  });
}
