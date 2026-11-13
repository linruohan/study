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
              'profile': {'band': null, 'focusDomainId': null},
              'plans': <Object?>[],
              'records': <Object?>[],
            };

  final Map<String, dynamic> knowledge;
  Map<String, Object?> userData;

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

  /// 假的知识点评论列表：测试里默认没有评论。
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
    return const [];
  }

  /// 假的知识点评论提交：直接回显正文，不落库。
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
    return {'id': 'fake_comment', 'body': body, 'deviceId': deviceId};
  }

  /// 假的知识点纠错列表：测试里默认没有纠错。
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
    return const [];
  }

  /// 假的知识点纠错提交：直接回显原文和建议，不落库。
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
    return {
      'id': 'fake_correction',
      'body': body,
      'deviceId': deviceId,
      'suggestedText': suggestedText,
    };
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

  /// 假的领域创建：回显入参，便于断言界面提交了什么。
  @override
  Future<Map<String, dynamic>> createDomain({
    String? id,
    required String categoryId,
    required String name,
    String glyph = '域',
    String color = '#7A6A54',
  }) async {
    _ensureOnline();
    return {
      'id': id ?? 'fake_domain',
      'categoryId': categoryId,
      'name': name,
      'glyph': glyph,
      'color': color,
      'concepts': const [],
    };
  }

  /// 假的知识创建：回显入参，便于断言界面提交了什么。
  @override
  Future<Map<String, dynamic>> createKnowledge({
    required String domainId,
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
      'domainId': domainId,
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
  }) async {
    _ensureOnline();
    return {'position': 1, 'point': point};
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPointChapters({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int pointPosition,
  }) async {
    _ensureOnline();
    return const [];
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
    return {'title': title, 'content': content};
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
    return {'chapterPosition': chapterPosition, 'title': title, 'content': content};
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
  }

  @override
  Future<Map<String, dynamic>> reviewPointCorrection({
    required String correctionId,
    required String reviewerDeviceId,
    required bool approve,
    int points = 0,
  }) async {
    _ensureOnline();
    return {
      'id': correctionId,
      'status': approve ? 'approved' : 'rejected',
      'pointsAwarded': approve ? points : 0,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPendingPointCorrections({int? limit, int? offset}) async {
    _ensureOnline();
    return const [];
  }

  @override
  Future<Map<String, dynamic>> fetchPointCredits(String deviceId, {int? limit, int? offset}) async {
    _ensureOnline();
    return {'deviceId': deviceId, 'balance': 0, 'items': const []};
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
    String? focusDomainId,
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
              'focusDomainId': focusDomainId,
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
