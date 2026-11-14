import 'package:flutter_test/flutter_test.dart';

import 'package:study_app/data/study_api.dart';
import 'package:study_app/data/study_repository.dart';
import 'package:study_app/plan_scheme/plan_scheme.dart';

/// 只关心方案接口的假实现；其余方法用 noSuchMethod 兜住接口签名。
class _FakeSchemeApi implements StudyApi {
  _FakeSchemeApi({this.result = const []});

  final List<Object> result;

  /// 下一次 fetchPlanSchemes 是否抛断网异常；用完自动复位。
  bool failNext = false;
  int fetchCount = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchPlanSchemes() async {
    fetchCount += 1;
    if (failNext) {
      failNext = false;
      throw StudyApiException('连不上本地服务，请确认服务已启动');
    }
    return [
      for (final item in result)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  test('PlanScheme.tryFromJson：关键字段缺失返回 null，好数据正常解析', () {
    expect(
      PlanScheme.tryFromJson({'name': 'x', 'stage': 'primary'}),
      isNull,
    );
    expect(
      PlanScheme.tryFromJson({'id': 'a', 'stage': 'primary'}),
      isNull,
    );
    expect(
      PlanScheme.tryFromJson({'id': 'a', 'name': 'x'}),
      isNull,
    );
    final ok = PlanScheme.tryFromJson({
      'id': 'scheme_x',
      'name': '方案',
      'stage': 'primary',
      'stageSort': 1,
      'dimensions': [
        {'id': 'd1', 'name': '语文', 'items': []},
        'bad-dim',
      ],
    });
    expect(ok, isNotNull);
    expect(ok!.dimensions.length, 1);
    expect(ok.dimensions.first.name, '语文');
  });

  test('fetchPlanSchemes：坏记录逐条跳过，不拖垮整份列表', () async {
    final api = _FakeSchemeApi(result: [
      {'id': 'scheme_ok', 'name': '好方案', 'stage': 'primary'},
      {'id': 'scheme_bad', 'name': '坏方案', 'stage': null},
      'not-a-map',
    ]);
    final repository = StudyRepository(api: api);
    final schemes = await repository.fetchPlanSchemes();
    expect(schemes.length, 1);
    expect(schemes.first.id, 'scheme_ok');
    expect(repository.planSchemesStale, isFalse);
  });

  test('fetchPlanSchemes：断网时保留旧列表并标记 stale，恢复后清除', () async {
    final api = _FakeSchemeApi(result: [
      {'id': 'scheme_ok', 'name': '好方案', 'stage': 'primary'},
    ]);
    final repository = StudyRepository(api: api);

    final first = await repository.fetchPlanSchemes();
    expect(first.length, 1);
    expect(repository.planSchemesStale, isFalse);

    api.failNext = true;
    final offline = await repository.fetchPlanSchemes();
    expect(offline.length, 1, reason: '离线时保留上次列表');
    expect(offline.first.id, 'scheme_ok');
    expect(repository.planSchemesStale, isTrue);

    // 恢复联网后自动清除标记。
    final restored = await repository.fetchPlanSchemes();
    expect(repository.planSchemesStale, isFalse);
    expect(restored.length, 1);
  });
}
