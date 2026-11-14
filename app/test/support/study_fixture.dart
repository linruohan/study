import 'dart:convert';
import 'dart:io';

import 'package:study_app/archive/archive_store.dart';
import 'package:study_app/archive/learning_record.dart';
import 'package:study_app/data/device_id_store.dart';
import 'package:study_app/data/study_api.dart';
import 'package:study_app/data/study_cache.dart';
import 'package:study_app/data/study_repository.dart';
import 'package:study_app/knowledge/age_band.dart';
import 'package:study_app/knowledge/knowledge_catalog.dart';
import 'package:study_app/knowledge/study_degree.dart';
import 'package:study_app/plan/plan_store.dart';
import 'package:study_app/plan/study_plan.dart';
import 'package:study_app/profile/profile_store.dart';

/// 读取由数据库接口导出的知识夹具，测试不依赖硬编码知识。
Map<String, dynamic> loadKnowledgeJson() {
  final file = File('test/fixtures/knowledge.json');
  final decoded = jsonDecode(file.readAsStringSync());
  return Map<String, dynamic>.from(decoded as Map);
}

/// 安装测试知识目录，并返回它。
KnowledgeCatalog installTestCatalog() {
  final catalog = KnowledgeCatalog.fromJson(loadKnowledgeJson());
  catalog.install();
  return catalog;
}

/// 按 id 取测试年龄档。
AgeBand testBand(String id) {
  return KnowledgeCatalog.instance.ageBandById(id)!;
}

/// 按 id 取测试学习程度。
StudyDegree testDegree(String id) {
  return KnowledgeCatalog.instance.degreeById(id)!;
}

/// 假接口：知识来自夹具，用户数据存在内存里。
class FakeStudyApi implements StudyApi {
  FakeStudyApi({Map<String, dynamic>? knowledge, Map<String, Object?>? userData})
      : knowledge = knowledge ?? loadKnowledgeJson(),
        userData = userData ??
            {
              'profile': {'band': null, 'focusCategoryId': null},
              'plans': <Object?>[],
              'records': <Object?>[],
            };

  final Map<String, dynamic> knowledge;
  Map<String, Object?> userData;

  /// 内存知识点互动存储：评论、纠错（含审核状态）、章节。
  final List<Map<String, dynamic>> pointComments = [];
  final List<Map<String, dynamic>> pointCorrections = [];
  final List<Map<String, dynamic>> pointChapters = [];

  /// 模拟断网：置为 true 后所有请求失败。
  bool offline = false;

  /// 成功保存的次数，便于断言确实同步过。
  int saveCount = 0;

  @override
  Future<Map<String, dynamic>> fetchKnowledge() async {
    _ensureOnline();
    return knowledge;
  }

  @override
  Future<Map<String, dynamic>> fetchUserData(String deviceId) async {
    _ensureOnline();
    return Map<String, dynamic>.from(userData);
  }

  @override
  Future<Map<String, dynamic>> saveUserData(
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    _ensureOnline();
    userData = Map<String, Object?>.from(data);
    saveCount++;
    return Map<String, dynamic>.from(userData);
  }

  /// 假的知识点评论列表：从内存存储按 ref 过滤。
  @override
  Future<List<Map<String, dynamic>>> fetchPointComments({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int position,
    int? limit,
    int? offset,
  }) async {
    _ensureOnline();
    return [
      for (final comment in pointComments)
        if (comment['conceptId'] == conceptId &&
            comment['ageBandId'] == ageBandId &&
            comment['degreeId'] == degreeId &&
            comment['position'] == position)
          Map<String, dynamic>.from(comment),
    ];
  }

  /// 假的知识点评论提交：追加进内存存储。
  @override
  Future<Map<String, dynamic>> createPointComment({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int position,
    required String deviceId,
    required String body,
  }) async {
    _ensureOnline();
    final comment = <String, dynamic>{
      'id': 'fake_comment_${pointComments.length + 1}',
      'conceptId': conceptId,
      'ageBandId': ageBandId,
      'degreeId': degreeId,
      'position': position,
      'deviceId': deviceId,
      'body': body,
    };
    pointComments.add(comment);
    return Map<String, dynamic>.from(comment);
  }

  /// 假的知识点纠错列表：从内存存储按 ref 过滤。
  @override
  Future<List<Map<String, dynamic>>> fetchPointCorrections({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int position,
    int? limit,
    int? offset,
  }) async {
    _ensureOnline();
    return [
      for (final correction in pointCorrections)
        if (correction['conceptId'] == conceptId &&
            correction['ageBandId'] == ageBandId &&
            correction['degreeId'] == degreeId &&
            correction['position'] == position)
          Map<String, dynamic>.from(correction),
    ];
  }

  /// 假的知识点纠错提交：追加进内存存储，状态待审。
  @override
  Future<Map<String, dynamic>> createPointCorrection({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int position,
    required String deviceId,
    required String body,
    String? suggestedText,
  }) async {
    _ensureOnline();
    final correction = <String, dynamic>{
      'id': 'fake_correction_${pointCorrections.length + 1}',
      'conceptId': conceptId,
      'ageBandId': ageBandId,
      'degreeId': degreeId,
      'position': position,
      'deviceId': deviceId,
      'body': body,
      'suggestedText': suggestedText,
      'status': 'pending',
      'pointsAwarded': 0,
    };
    pointCorrections.add(correction);
    return Map<String, dynamic>.from(correction);
  }

  /// 假的分类创建：把入参原样返回，方便断言界面收到了什么。
  @override
  Future<Map<String, dynamic>> createCategory({
    required String id,
    String? parentId,
    required String name,
    String question = '',
    String glyph = '类',
    String color = '#7A6A54',
  }) async {
    _ensureOnline();
    return {
      'id': id,
      'parentId': parentId,
      'name': name,
      'question': question,
      'glyph': glyph,
      'color': color,
    };
  }

  /// 假的分类修改：回显新的名称与描述，便于断言界面提交了什么。
  @override
  Future<Map<String, dynamic>> updateCategory({
    required String id,
    required String name,
    String question = '',
  }) async {
    _ensureOnline();
    return {
      'id': id,
      'name': name,
      'question': question,
      'glyph': '类',
      'color': '#7A6A54',
    };
  }

  /// 假的知识创建：回显入参，便于断言界面提交了什么。
  @override
  Future<Map<String, dynamic>> createKnowledge({
    required String categoryId,
    required String ageBandId,
    required String topic,
    String? doing,
    String? praise,
    String? check,
    String? answer,
    String? note,
    String? glyph,
  }) async {
    _ensureOnline();
    return {
      'id': 'fake_knowledge',
      'depth': 0,
      'topic': topic,
      'categoryId': categoryId,
      'ageBandId': ageBandId,
    };
  }

  /// 假的知识点创建：位置按入参模拟为 1。
  @override
  Future<Map<String, dynamic>> addKnowledgePoint({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required String point,
    String? cognitiveLevel,
  }) async {
    _ensureOnline();
    return {'position': 1, 'point': point, 'cognitiveLevel': cognitiveLevel ?? 'remember'};
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPointChapters({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int pointPosition,
  }) async {
    _ensureOnline();
    return [
      for (final chapter in pointChapters)
        if (chapter['conceptId'] == conceptId &&
            chapter['ageBandId'] == ageBandId &&
            chapter['degreeId'] == degreeId &&
            chapter['pointPosition'] == pointPosition)
          Map<String, dynamic>.from(chapter),
    ];
  }

  @override
  Future<Map<String, dynamic>> createPointChapter({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int pointPosition,
    required String title,
    String? content,
  }) async {
    _ensureOnline();
    // 位置接在该知识点现有章节末尾，与服务端口径一致。
    var position = 0;
    for (final chapter in pointChapters) {
      if (chapter['conceptId'] == conceptId &&
          chapter['ageBandId'] == ageBandId &&
          chapter['degreeId'] == degreeId &&
          chapter['pointPosition'] == pointPosition &&
          (chapter['chapterPosition'] as int) > position) {
        position = chapter['chapterPosition'] as int;
      }
    }
    final chapter = <String, dynamic>{
      'id': 'fake_chapter_${pointChapters.length + 1}',
      'conceptId': conceptId,
      'ageBandId': ageBandId,
      'degreeId': degreeId,
      'pointPosition': pointPosition,
      'chapterPosition': position + 1,
      'title': title,
      'content': content,
    };
    pointChapters.add(chapter);
    return Map<String, dynamic>.from(chapter);
  }

  @override
  Future<Map<String, dynamic>> updatePointChapter({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int pointPosition,
    required int chapterPosition,
    required String title,
    String? content,
  }) async {
    _ensureOnline();
    for (var i = 0; i < pointChapters.length; i++) {
      final chapter = pointChapters[i];
      if (chapter['conceptId'] == conceptId &&
          chapter['ageBandId'] == ageBandId &&
          chapter['degreeId'] == degreeId &&
          chapter['pointPosition'] == pointPosition &&
          chapter['chapterPosition'] == chapterPosition) {
        final updated = Map<String, dynamic>.from(chapter)
          ..['title'] = title
          ..['content'] = content;
        pointChapters[i] = updated;
        return Map<String, dynamic>.from(updated);
      }
    }
    throw StudyApiException('章节不存在');
  }

  @override
  Future<void> deletePointChapter({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int pointPosition,
    required int chapterPosition,
  }) async {
    _ensureOnline();
    pointChapters.removeWhere(
      (chapter) =>
          chapter['conceptId'] == conceptId &&
          chapter['ageBandId'] == ageBandId &&
          chapter['degreeId'] == degreeId &&
          chapter['pointPosition'] == pointPosition &&
          chapter['chapterPosition'] == chapterPosition,
    );
  }

  @override
  Future<Map<String, dynamic>> reviewPointCorrection({
    required String correctionId,
    required String reviewerDeviceId,
    required bool approve,
    int points = 0,
  }) async {
    _ensureOnline();
    for (var i = 0; i < pointCorrections.length; i++) {
      if (pointCorrections[i]['id'] == correctionId) {
        pointCorrections[i] = Map<String, dynamic>.from(pointCorrections[i])
          ..['status'] = approve ? 'approved' : 'rejected'
          ..['pointsAwarded'] = approve ? points : 0
          ..['reviewerDeviceId'] = reviewerDeviceId;
        return Map<String, dynamic>.from(pointCorrections[i]);
      }
    }
    throw StudyApiException('纠错不存在');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPendingPointCorrections({int? limit, int? offset}) async {
    _ensureOnline();
    return [
      for (final correction in pointCorrections)
        if (correction['status'] == 'pending') Map<String, dynamic>.from(correction),
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDegreeApplications({String status = 'pending'}) async {
    _ensureOnline();
    return const [];
  }

  @override
  Future<Map<String, dynamic>> reviewDegreeApplication({
    required String applicationId,
    required bool approve,
  }) async {
    _ensureOnline();
    return {'application': {'id': applicationId, 'status': approve ? 'approved' : 'rejected'}};
  }

  @override
  Future<Map<String, dynamic>> fetchPointCredits(String deviceId, {int? limit, int? offset}) async {
    _ensureOnline();
    // 余额 = 该设备全部纠错已发放积分之和，与服务端口径一致。
    var balance = 0;
    for (final correction in pointCorrections) {
      if (correction['deviceId'] == deviceId) {
        balance += (correction['pointsAwarded'] as int?) ?? 0;
      }
    }
    return {
      'deviceId': deviceId,
      'balance': balance,
      'items': [
        for (final correction in pointCorrections)
          if (correction['deviceId'] == deviceId && (correction['pointsAwarded'] as int? ?? 0) > 0)
            {
              'amount': correction['pointsAwarded'],
              'reason': '知识点纠错审核通过奖励',
              'correctionId': correction['id'],
            },
      ],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPlanSchemes() async {
    _ensureOnline();
    return const [];
  }

  @override
  Future<Map<String, dynamic>> fetchPlanScheme(String id) async {
    _ensureOnline();
    throw StudyApiException('方案不存在');
  }

  @override
  Future<Map<String, dynamic>> createPlanScheme(Map<String, dynamic> input) async {
    _ensureOnline();
    return Map<String, dynamic>.from(input);
  }

  @override
  Future<Map<String, dynamic>> updatePlanScheme(String id, Map<String, dynamic> input) async {
    _ensureOnline();
    return Map<String, dynamic>.from(input);
  }

  @override
  Future<void> deletePlanScheme(String id) async {
    _ensureOnline();
  }

  @override
  Future<Map<String, dynamic>> clonePlanScheme(String id) async {
    _ensureOnline();
    return {'id': id};
  }

  void _ensureOnline() {
    if (offline) {
      throw StudyApiException('测试断网');
    }
  }
}

/// 内存缓存：测试不碰真实文件，避免 widget 测试里的异步 I/O 卡住。
class MemoryStudyCache implements StudyCache {
  MemoryStudyCache({this.initial});

  /// 预置的缓存内容，用来模拟上一次的离线数据。
  CachedStudy? initial;

  CachedStudy? _current;

  /// 最近一次写入的内容，便于断言。
  CachedStudy? get current => _current ?? initial;

  @override
  Future<CachedStudy?> read() async => _current ?? initial;

  @override
  Future<void> write({
    required Map<String, Object?> knowledge,
    required Map<String, Object?> userData,
    required bool pending,
  }) async {
    _current = CachedStudy(
      knowledge: knowledge,
      userData: userData,
      pending: pending,
    );
  }

  @override
  Future<void> clear() async {
    _current = null;
    initial = null;
  }
}

/// 内存设备标识：固定用同一个 id，测试之间互不影响。
class MemoryDeviceIdStore implements DeviceIdStore {
  MemoryDeviceIdStore([this.id = 'test-device']);

  final String id;

  @override
  Future<String> read() async => id;
}

/// 测试用的一套数据：仓库、假接口、三个写入入口和临时目录。
class TestStudy {
  TestStudy._(this.directory, this.api, this.repository, this.cache);

  final Directory directory;
  final FakeStudyApi api;
  final StudyRepository repository;
  final MemoryStudyCache cache;

  late final ProfileStore profileStore = ProfileStore(repository);
  late final PlanStore planStore = PlanStore(repository);
  late final ArchiveStore archiveStore =
      ArchiveStore(repository, directory: directory);

  /// 建一套测试数据；默认还没选年龄档。
  static Future<TestStudy> create({
    String? band,
    String? focusCategoryId,
    List<StudyPlan> plans = const [],
    List<LearningRecord> records = const [],
    FakeStudyApi? api,
    Directory? directory,
    MemoryStudyCache? cache,
  }) async {
    final dir = directory ?? Directory.systemTemp.createTempSync('lumen_test_');
    final fake = api ??
        FakeStudyApi(
          userData: {
            'profile': {
              'band': band,
              'focusCategoryId': focusCategoryId,
            },
            'plans': [for (final plan in plans) plan.toJson()],
            'records': [for (final record in records) record.toJson()],
          },
        );
    final memoryCache = cache ?? MemoryStudyCache();
    final repository = StudyRepository(
      api: fake,
      cache: memoryCache,
      device: MemoryDeviceIdStore(),
    );
    await repository.load();
    return TestStudy._(dir, fake, repository, memoryCache);
  }

  /// 清理临时目录。
  void dispose() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }
}
