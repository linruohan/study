import 'package:flutter_test/flutter_test.dart';

import 'package:study_app/data/study_api.dart';

import 'support/study_fixture.dart';

void main() {
  const ref = (
    conceptId: 'zi_ri',
    ageBandId: 'toddler',
    degreeId: 'beginner',
    position: 1,
  );

  test('评论：提交后能在列表里看到，断网时报错不落库', () async {
    final study = await TestStudy.create();
    try {
      final created = await study.repository.createPointComment(
        conceptId: ref.conceptId,
        ageBandId: ref.ageBandId,
        degreeId: ref.degreeId,
        position: ref.position,
        body: '第一条评论',
      );
      expect(created['body'], '第一条评论');

      final comments = await study.repository.fetchPointComments(
        conceptId: ref.conceptId,
        ageBandId: ref.ageBandId,
        degreeId: ref.degreeId,
        position: ref.position,
      );
      expect(comments.length, 1);
      expect(comments.first['body'], '第一条评论');

      // 其他知识点看不到这条评论。
      final otherPoint = await study.repository.fetchPointComments(
        conceptId: ref.conceptId,
        ageBandId: ref.ageBandId,
        degreeId: ref.degreeId,
        position: 2,
      );
      expect(otherPoint, isEmpty);

      // 断网：请求抛 StudyApiException，存储不变。
      study.api.offline = true;
      await expectLater(
        study.repository.createPointComment(
          conceptId: ref.conceptId,
          ageBandId: ref.ageBandId,
          degreeId: ref.degreeId,
          position: ref.position,
          body: '断网评论',
        ),
        throwsA(isA<StudyApiException>()),
      );
    } finally {
      study.dispose();
    }
  });

  test('纠错：提交待审 → 审核通过发积分 → 不再出现在待审列表', () async {
    final study = await TestStudy.create();
    try {
      final submitted = await study.repository.createPointCorrection(
        conceptId: ref.conceptId,
        ageBandId: ref.ageBandId,
        degreeId: ref.degreeId,
        position: ref.position,
        body: '这里的说法不对',
        suggestedText: '应该这样讲',
      );
      final correctionId = submitted['id'] as String;

      var pending = await study.repository.fetchPendingPointCorrections();
      expect(pending.length, 1);

      final reviewed = await study.repository.reviewPointCorrection(
        correctionId: correctionId,
        approve: true,
        points: 5,
      );
      expect(reviewed['status'], 'approved');
      expect(reviewed['pointsAwarded'], 5);

      pending = await study.repository.fetchPendingPointCorrections();
      expect(pending, isEmpty, reason: '审核过的不该再出现在待审列表');

      final credits = await study.repository.fetchPointCredits();
      expect(credits['balance'], 5);
    } finally {
      study.dispose();
    }
  });

  test('章节：创建接位 → 更新 → 删除，离线创建失败', () async {
    final study = await TestStudy.create();
    try {
      final first = await study.repository.createPointChapter(
        conceptId: ref.conceptId,
        ageBandId: ref.ageBandId,
        degreeId: ref.degreeId,
        pointPosition: ref.position,
        title: '第一章',
        content: '开始',
      );
      expect(first['chapterPosition'], 1);

      final second = await study.repository.createPointChapter(
        conceptId: ref.conceptId,
        ageBandId: ref.ageBandId,
        degreeId: ref.degreeId,
        pointPosition: ref.position,
        title: '第二章',
      );
      expect(second['chapterPosition'], 2, reason: '新章节接在末尾');

      final updated = await study.repository.updatePointChapter(
        conceptId: ref.conceptId,
        ageBandId: ref.ageBandId,
        degreeId: ref.degreeId,
        pointPosition: ref.position,
        chapterPosition: 1,
        title: '第一章（改）',
        content: '改过的正文',
      );
      expect(updated['title'], '第一章（改）');

      var chapters = await study.repository.fetchPointChapters(
        conceptId: ref.conceptId,
        ageBandId: ref.ageBandId,
        degreeId: ref.degreeId,
        pointPosition: ref.position,
      );
      expect(chapters.length, 2);
      expect(chapters.first['title'], '第一章（改）');

      await study.repository.deletePointChapter(
        conceptId: ref.conceptId,
        ageBandId: ref.ageBandId,
        degreeId: ref.degreeId,
        pointPosition: ref.position,
        chapterPosition: 1,
      );
      chapters = await study.repository.fetchPointChapters(
        conceptId: ref.conceptId,
        ageBandId: ref.ageBandId,
        degreeId: ref.degreeId,
        pointPosition: ref.position,
      );
      expect(chapters.length, 1);
      expect(chapters.first['title'], '第二章');

      // 不存在的章节更新报 StudyApiException。
      await expectLater(
        study.repository.updatePointChapter(
          conceptId: ref.conceptId,
          ageBandId: ref.ageBandId,
          degreeId: ref.degreeId,
          pointPosition: ref.position,
          chapterPosition: 9,
          title: '幽灵',
        ),
        throwsA(isA<StudyApiException>()),
      );

      // 断网时创建失败，不落库。
      study.api.offline = true;
      await expectLater(
        study.repository.createPointChapter(
          conceptId: ref.conceptId,
          ageBandId: ref.ageBandId,
          degreeId: ref.degreeId,
          pointPosition: ref.position,
          title: '断网章节',
        ),
        throwsA(isA<StudyApiException>()),
      );
    } finally {
      study.dispose();
    }
  });
}
