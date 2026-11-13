import '../archive/archive_file.dart';
import '../archive/learning_record.dart';
import '../knowledge/knowledge_catalog.dart';
import '../plan/study_plan.dart';
import '../profile/study_profile.dart';
import 'device_id_store.dart';
import 'sage_api.dart';
import 'sage_service.dart';
import 'study_api.dart';
import 'study_cache.dart';

/// 一次加载的结果：知识目录 + 设备数据。
class StudySnapshot {
  const StudySnapshot({
    required this.catalog,
    required this.profile,
    required this.plans,
    required this.archive,
    required this.fromCache,
  });

  final KnowledgeCatalog catalog;
  final StudyProfile profile;
  final List<StudyPlan> plans;
  final ArchiveFile archive;

  /// true 表示这次是断网兜底，用的是上次缓存。
  final bool fromCache;
}

/// 数据仓库：负责远程读写、本地缓存和内存状态。
///
/// 应用只通过它拿数据；知识、设置、计划、记录都不再写进应用代码。
class StudyRepository {
  StudyRepository({
    StudyApi? api,
    StudyCache? cache,
    DeviceIdStore? device,
    SageService? sage,
  })  : _api = api ?? HttpStudyApi(),
        _cache = cache ?? FileStudyCache(),
        _device = device ?? FileDeviceIdStore(),
        _sage = sage;

  final StudyApi _api;
  final StudyCache _cache;
  final DeviceIdStore _device;
  SageService? _sage;

  KnowledgeCatalog? _catalog;
  StudyProfile _profile = const StudyProfile();
  List<StudyPlan> _plans = const [];
  ArchiveFile _archive = const ArchiveFile(records: []);

  Map<String, Object?>? _knowledgeJson;
  String? _deviceId;
  bool _pending = false;
  StudySnapshot? _loaded;

  /// 当前知识目录；加载完成后才有值。
  KnowledgeCatalog get catalog {
    final value = _catalog;
    if (value == null) {
      throw StateError('知识库还没有加载');
    }
    return value;
  }

  StudyProfile get profile => _profile;
  List<StudyPlan> get plans => List.unmodifiable(_plans);
  ArchiveFile get archive => _archive;

  /// 智者模块：填名字、看贡献、提交知识或知识点。
  SageService get sage {
    if (_sage == null) {
      final deviceId = _deviceId;
      if (deviceId == null) {
        throw StateError('设备 id 还未读取，请先加载数据');
      }
      _sage = HttpSageService(
        api: HttpSageApi(),
        deviceId: deviceId,
      );
    }
    return _sage!;
  }

  /// 是否已经成功加载过一次数据。
  bool get isLoaded => _loaded != null;

  /// 上次加载得到的快照；没有加载过时为 null。
  StudySnapshot? get loadedSnapshot => _loaded;

  /// 是否有还没同步到服务端的本地修改。
  bool get pending => _pending;

  /// 加载知识库与设备数据。
  ///
  /// 先尝试网络；失败时用最近一次缓存。若有离线修改，
  /// 会先把缓存推回服务端，再做拉取。
  Future<StudySnapshot> load() async {
    final deviceId = await _device.read();
    _deviceId = deviceId;
    final cached = await _cache.read();
    var cachedPending = cached?.pending ?? false;

    if (cached != null && cached.pending) {
      try {
        await _api.saveUserData(deviceId, cached.userData);
        await _cache.write(
          knowledge: cached.knowledge,
          userData: cached.userData,
          pending: false,
        );
        cachedPending = false;
      } catch (_) {
        // 仍然连不上就继续用缓存，下次启动再试。
      }
    }

    try {
      final responses = await Future.wait([
        _api.fetchKnowledge(),
        _api.fetchUserData(deviceId),
      ]);
      final knowledgeJson = responses[0];
      final userJson = responses[1];

      _catalog = KnowledgeCatalog.fromJson(knowledgeJson)..install();
      _knowledgeJson = knowledgeJson;
      _applyUserData(userJson);
      _pending = false;
      await _cache.write(
        knowledge: knowledgeJson,
        userData: _userDataJson(),
        pending: false,
      );
      _loaded = _snapshot(fromCache: false);
      return _loaded!;
    } catch (error) {
      if (cached == null) {
        rethrow;
      }
      _catalog = KnowledgeCatalog.fromJson(cached.knowledge)..install();
      _knowledgeJson = cached.knowledge;
      _applyUserData(cached.userData);
      _pending = cachedPending;
      _loaded = _snapshot(fromCache: true);
      return _loaded!;
    }
  }


  String get deviceId {
    final id = _deviceId;
    if (id == null) throw StateError('设备 id 还未加载');
    return id;
  }

  Future<List<Map<String, dynamic>>> fetchPointComments({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int position,
    int? limit,
    int? offset,
  }) => _api.fetchPointComments(conceptId: conceptId, ageBandId: ageBandId, degreeId: degreeId, position: position, limit: limit, offset: offset);

  Future<Map<String, dynamic>> createPointComment({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int position,
    required String body,
  }) => _api.createPointComment(conceptId: conceptId, ageBandId: ageBandId, degreeId: degreeId, position: position, deviceId: deviceId, body: body);

  Future<List<Map<String, dynamic>>> fetchPointCorrections({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int position,
    int? limit,
    int? offset,
  }) => _api.fetchPointCorrections(conceptId: conceptId, ageBandId: ageBandId, degreeId: degreeId, position: position, limit: limit, offset: offset);

  Future<Map<String, dynamic>> createPointCorrection({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int position,
    required String body,
    String? suggestedText,
  }) => _api.createPointCorrection(conceptId: conceptId, ageBandId: ageBandId, degreeId: degreeId, position: position, deviceId: deviceId, body: body, suggestedText: suggestedText);


  Future<Map<String, dynamic>> createCategory({
    required String id,
    String? parentId,
    required String name,
    String question = '',
    String glyph = '类',
    String color = '#7A6A54',
  }) => _api.createCategory(id: id, parentId: parentId, name: name, question: question, glyph: glyph, color: color);

  /// 修改分类的名称与描述；成功后由界面重新拉取知识库。
  Future<Map<String, dynamic>> updateCategory({
    required String id,
    required String name,
    String question = '',
  }) => _api.updateCategory(id: id, name: name, question: question);

  /// 在指定分类下新建学习领域；创建后由界面触发知识库刷新。
  Future<Map<String, dynamic>> createDomain({
    String? id,
    required String categoryId,
    required String name,
    String glyph = '域',
    String color = '#7A6A54',
  }) => _api.createDomain(
    id: id,
    categoryId: categoryId,
    name: name,
    glyph: glyph,
    color: color,
  );

  /// 在指定领域下新建一条知识；创建后由界面刷新知识目录。
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
  }) => _api.createKnowledge(
    domainId: domainId,
    ageBandId: ageBandId,
    topic: topic,
    doing: doing,
    praise: praise,
    check: check,
    answer: answer,
    note: note,
    glyph: glyph,
  );

  /// 在某个学习程度下追加知识点。
  Future<Map<String, dynamic>> addKnowledgePoint({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required String point,
  }) => _api.addKnowledgePoint(
    conceptId: conceptId,
    ageBandId: ageBandId,
    degreeId: degreeId,
    point: point,
  );

  Future<Map<String, dynamic>> reviewPointCorrection({
    required String correctionId,
    required bool approve,
    int points = 0,
  }) => _api.reviewPointCorrection(
    correctionId: correctionId,
    reviewerDeviceId: deviceId,
    approve: approve,
    points: points,
  );

  Future<List<Map<String, dynamic>>> fetchPointChapters({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int pointPosition,
  }) => _api.fetchPointChapters(conceptId: conceptId, ageBandId: ageBandId, degreeId: degreeId, pointPosition: pointPosition);

  Future<Map<String, dynamic>> createPointChapter({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int pointPosition,
    required String title,
    String? content,
  }) => _api.createPointChapter(conceptId: conceptId, ageBandId: ageBandId, degreeId: degreeId, pointPosition: pointPosition, title: title, content: content);

  Future<Map<String, dynamic>> updatePointChapter({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int pointPosition,
    required int chapterPosition,
    required String title,
    String? content,
  }) => _api.updatePointChapter(conceptId: conceptId, ageBandId: ageBandId, degreeId: degreeId, pointPosition: pointPosition, chapterPosition: chapterPosition, title: title, content: content);

  Future<void> deletePointChapter({
    required String conceptId,
    required String ageBandId,
    required String degreeId,
    required int pointPosition,
    required int chapterPosition,
  }) => _api.deletePointChapter(conceptId: conceptId, ageBandId: ageBandId, degreeId: degreeId, pointPosition: pointPosition, chapterPosition: chapterPosition);

  Future<Map<String, dynamic>> fetchPointCredits({int? limit, int? offset}) => _api.fetchPointCredits(deviceId, limit: limit, offset: offset);

  Future<List<Map<String, dynamic>>> fetchPendingPointCorrections({int? limit, int? offset}) => _api.fetchPendingPointCorrections(limit: limit, offset: offset);

  /// 仅刷新知识库并更新本地缓存（保留当前设备数据）。
  Future<KnowledgeCatalog> reloadKnowledge() async {
    final deviceId = await _device.read();
    _deviceId = deviceId;
    final knowledgeJson = await _api.fetchKnowledge();
    final catalog = KnowledgeCatalog.fromJson(knowledgeJson)..install();
    _catalog = catalog;
    _knowledgeJson = knowledgeJson;
    final cached = await _cache.read();
    await _cache.write(
      knowledge: knowledgeJson,
      userData: cached?.userData ?? _userDataJson(),
      pending: cached?.pending ?? _pending,
    );
    if (_loaded != null) {
      _loaded = _snapshot(fromCache: _loaded!.fromCache);
    }
    return catalog;
  }

  /// 保存设置。
  Future<void> saveProfile(StudyProfile profile) async {
    _profile = profile;
    await _push();
  }

  /// 保存全部计划。
  Future<void> savePlans(List<StudyPlan> plans) async {
    _plans = [...plans]..sort((a, b) => a.startAt.compareTo(b.startAt));
    await _push();
  }

  /// 保存整份学习档案。
  Future<void> saveArchive(ArchiveFile archive) async {
    _archive = archive;
    await _push();
  }

  /// 写缓存并同步服务端；写库成功后回读一次，内存以数据库为准。
  ///
  /// 同步失败只标记待推送，不打断界面，下次加载时会再试。
  Future<void> _push() async {
    final knowledge = _knowledgeJson;
    final deviceId = _deviceId;
    if (knowledge == null || deviceId == null) {
      return;
    }
    final data = _userDataJson();
    await _cache.write(
      knowledge: knowledge,
      userData: data,
      pending: true,
    );
    try {
      await _api.saveUserData(deviceId, data);
      _pending = false;
      try {
        // 回读数据库，页面随后展示的就是库里真实保存的内容。
        _applyUserData(await _api.fetchUserData(deviceId));
      } catch (_) {
        // 回读失败时先保留刚写入的内容，下次加载会再同步。
      }
      await _cache.write(
        knowledge: knowledge,
        userData: _userDataJson(),
        pending: false,
      );
    } catch (_) {
      _pending = true;
    }
  }

  /// 把接口数据读进内存；坏记录逐条跳过，不让整份数据失败。
  void _applyUserData(Map<String, Object?> userJson) {
    final rawProfile = userJson['profile'];
    _profile = rawProfile is Map
        ? StudyProfile.fromJson(Map<String, Object?>.from(rawProfile))
        : const StudyProfile();

    final plans = <StudyPlan>[];
    final rawPlans = userJson['plans'];
    if (rawPlans is List) {
      for (final item in rawPlans) {
        if (item is! Map) {
          continue;
        }
        final plan = StudyPlan.fromJson(Map<String, Object?>.from(item));
        if (plan != null) {
          plans.add(plan);
        }
      }
    }
    plans.sort((a, b) => a.startAt.compareTo(b.startAt));
    _plans = plans;

    final records = <LearningRecord>[];
    final rawRecords = userJson['records'];
    if (rawRecords is List) {
      for (final item in rawRecords) {
        if (item is! Map) {
          continue;
        }
        try {
          records.add(
            LearningRecord.fromJson(Map<String, Object?>.from(item)),
          );
        } catch (_) {
          // 单条坏记录直接跳过。
        }
      }
    }
    _archive = ArchiveFile(records: records);
  }

  /// 内存状态转成接口和缓存共用的 JSON。
  Map<String, Object?> _userDataJson() {
    return {
      'profile': _profile.toJson(),
      'plans': [for (final plan in _plans) plan.toJson()],
      'records': [for (final record in _archive.records) record.toJson()],
    };
  }

  StudySnapshot _snapshot({required bool fromCache}) {
    return StudySnapshot(
      catalog: catalog,
      profile: _profile,
      plans: plans,
      archive: _archive,
      fromCache: fromCache,
    );
  }
}
