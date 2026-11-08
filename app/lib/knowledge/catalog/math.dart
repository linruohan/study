import 'package:flutter/material.dart';

import '../age_band.dart';
import '../concept.dart';
import '../domain.dart';

/// 数领域：从数实物到统计与微积分入门，深浅由 depth 表示。
const mathDomain = LearningDomain(
  id: 'math',
  name: '数',
  glyph: '数',
  color: Color(0xFF3E6F8C),
  concepts: [
    Concept(
      id: 'count_objects',
      domainId: 'math',
      depth: 0,
      variants: {
        AgeBand.toddler: ConceptVariant(
          topic: '数三个苹果',
          glyph: '3',
          doing: '点着数出三个苹果',
          praise: '你能数出三个苹果',
          check: '再数一遍，还是三个吗？',
          answer: '一样多。前后数得一样，就是数对了。',
          note: '用手指着一个一个数。',
        ),
        AgeBand.lowerPrimary: ConceptVariant(
          topic: '20 以内加减',
          glyph: '+',
          doing: '算出 8+5',
          praise: '你能算出 8+5',
          check: '8+5 和 5+8 一样吗？',
          answer: '一样，交换顺序结果不变。',
          note: '可以在纸上画小棍。',
        ),
      },
    ),
    Concept(
      id: 'fraction',
      domainId: 'math',
      depth: 1,
      prerequisites: ['count_objects'],
      variants: {
        AgeBand.upperPrimary: ConceptVariant(
          topic: '分数和面积',
          glyph: '½',
          doing: '把一张纸分成四份，涂出其中的三分之一',
          praise: '你能用面积说清一个分数',
          check: '同一张纸，四分之一和三分之一哪个大？',
          answer: '三分之一大，因为分的份数少。',
        ),
        AgeBand.middleSchool: ConceptVariant(
          topic: '用方程表示关系',
          glyph: '=',
          doing: '把一个生活问题写成方程',
          praise: '你能把一句话写成方程',
          check: '等号两边各代表什么？',
          answer: '一边是总量，一边是各部分之和。',
        ),
        AgeBand.highSchool: ConceptVariant(
          topic: '函数与数列',
          glyph: 'ƒ',
          doing: '写出一个数列的前四项，并说明它的规律',
          praise: '你能用规律写出后面的项',
          check: '换一个起始项，规律还成立吗？',
          answer: '先写通项，再代进去验证。',
        ),
      },
    ),
    Concept(
      id: 'statistics',
      domainId: 'math',
      depth: 2,
      prerequisites: ['fraction'],
      variants: {
        AgeBand.middleSchool: ConceptVariant(
          topic: '看一组数据的波动',
          glyph: '≈',
          doing: '算出这组数的平均数和范围',
          praise: '你能说出一组数的平均和范围',
          check: '平均数能代表每一个数吗？',
          answer: '不能，它只说明总体位置。',
        ),
        AgeBand.highSchool: ConceptVariant(
          topic: '概率与抽样',
          glyph: 'P',
          doing: '说清一次抽样的范围和误差来源',
          praise: '你能说清抽样可能哪里偏',
          check: '换一群人来抽，结果会一样吗？',
          answer: '不一定，要看抽样范围和人数。',
        ),
        AgeBand.college: ConceptVariant(
          topic: '微积分或统计入门',
          glyph: '∫',
          doing: '选一门，读完一节并写出一个可复算的步骤',
          praise: '你能写出可复算的一步',
          check: '别人照这一步能算出来吗？',
          answer: '把数据和公式都写清楚。',
        ),
        AgeBand.beyondSchool: ConceptVariant(
          topic: '核对健康信息里的数字',
          glyph: '%',
          doing: '找出这则信息里的基数和时间范围',
          praise: '你能核对一个百分比背后的基数',
          check: '这个百分比是多少人中得出的？',
          answer: '没有基数，百分比就不说明风险大小。',
          note: '看到的数字先问从哪来。',
        ),
      },
    ),
  ],
);
