import 'package:flutter/material.dart';

import '../age_band.dart';
import '../concept.dart';
import '../domain.dart';

/// 生活与安全领域：覆盖「衣食住行」里的安全常识，从远离火到合同条款。
const lifeDomain = LearningDomain(
  id: 'life',
  name: '生活与安全',
  glyph: '安',
  color: Color(0xFF6F7A63),
  concepts: [
    Concept(
      id: 'fire_safety',
      domainId: 'life',
      depth: 0,
      variants: {
        AgeBand.toddler: ConceptVariant(
          topic: '看见火要远离',
          glyph: '火',
          doing: '指出哪里有火，并去找大人',
          praise: '你能看见火就找大人',
          check: '看见火，先做什么？',
          answer: '离远一点，再叫大人。',
          note: '灶台、打火机、蜡烛都算火。',
        ),
        AgeBand.lowerPrimary: ConceptVariant(
          topic: '火需要空气',
          glyph: '火',
          doing: '说清盖上盖子为什么火会变小',
          praise: '你能说出火需要空气',
          check: '把杯子扣在蜡烛上，会怎样？',
          answer: '空气用完了，火就灭。',
          note: '这一步由大人操作。',
        ),
        AgeBand.middleSchool: ConceptVariant(
          topic: '燃烧三要素',
          glyph: '火',
          doing: '写出可燃物、助燃物和着火点',
          praise: '你能说出燃烧的三个条件',
          check: '少一个条件，还能烧起来吗？',
          answer: '三个同时有，才会持续燃烧。',
        ),
        AgeBand.college: ConceptVariant(
          topic: '火灾动力学与逃生限制',
          glyph: '火',
          doing: '读一份消防说明，写出两条逃生限制',
          praise: '你能说出火场里不能做的事',
          check: '为什么不能乘电梯？',
          answer: '断电和烟气会让电梯停住。',
        ),
      },
    ),
    Concept(
      id: 'electric_safety',
      domainId: 'life',
      depth: 1,
      prerequisites: ['fire_safety'],
      variants: {
        AgeBand.lowerPrimary: ConceptVariant(
          topic: '不碰插座',
          glyph: '电',
          doing: '指出家里不能用手碰的两处',
          praise: '你能指出不能碰的插座',
          check: '手湿的时候能碰开关吗？',
          answer: '不能，先擦干，再叫大人。',
        ),
        AgeBand.upperPrimary: ConceptVariant(
          topic: '湿手不碰开关',
          glyph: '电',
          doing: '说出一个湿手用电的危险',
          praise: '你能说出湿手用电的危险',
          check: '电器进水后第一步做什么？',
          answer: '先断电，再由大人处理。',
        ),
        AgeBand.middleSchool: ConceptVariant(
          topic: '家庭电路和保险',
          glyph: '电',
          doing: '说清保险丝或断路器在保护什么',
          praise: '你能说出保险装置在保护什么',
          check: '电流过大时，谁先断开？',
          answer: '保险丝或断路器先断开。',
        ),
        AgeBand.highSchool: ConceptVariant(
          topic: '功率与安全余量',
          glyph: '电',
          doing: '算出一个插排还能接多少瓦',
          praise: '你能算出插排的安全余量',
          check: '标称功率是上限，还是起点？',
          answer: '是上限，不能贴着上限长期用。',
        ),
        AgeBand.beyondSchool: ConceptVariant(
          topic: '跳闸以后先做什么',
          glyph: '电',
          doing: '写出跳闸后的检查顺序',
          praise: '你能写出跳闸后的检查顺序',
          check: '合闸之前要先做什么？',
          answer: '先拔掉大功率电器，再查线路。',
        ),
      },
    ),
    Concept(
      id: 'food_expiry',
      domainId: 'life',
      depth: 2,
      variants: {
        AgeBand.lowerPrimary: ConceptVariant(
          topic: '看保质期',
          glyph: '食',
          doing: '找出一盒牛奶的保质日期',
          praise: '你能找到保质期',
          check: '今天在保质期内吗？',
          answer: '把今天和日期比一比。',
        ),
        AgeBand.upperPrimary: ConceptVariant(
          topic: '看清保存条件',
          glyph: '食',
          doing: '说出这盒东西要不要冷藏',
          praise: '你能看懂保存条件',
          check: '放常温会怎样？',
          answer: '可能提前坏掉。',
        ),
        AgeBand.beyondSchool: ConceptVariant(
          topic: '判断还能不能吃',
          glyph: '食',
          doing: '按日期、外观和保存条件写下判断',
          praise: '你能按三条线索判断食物',
          check: '只看日期够吗？',
          answer: '不够，还要看保存条件和是否变质。',
        ),
      },
    ),
    Concept(
      id: 'contract',
      domainId: 'life',
      depth: 3,
      variants: {
        AgeBand.college: ConceptVariant(
          topic: '合同里先看哪几条',
          glyph: '约',
          doing: '在一份合同里标出期限、金额和解除条件',
          praise: '你能找出合同的三处关键条款',
          check: '哪一条说了怎么退出？',
          answer: '解除或终止的那一条。',
        ),
        AgeBand.beyondSchool: ConceptVariant(
          topic: '签字前的三个问题',
          glyph: '约',
          doing: '写下：和谁签、做什么、怎么退出',
          praise: '你能在签字前问清三件事',
          check: '口头承诺和纸上写的不同，以哪个为准？',
          answer: '以书面条款为准，不确定就先问。',
          note: '这不是法律意见。',
        ),
      },
    ),
  ],
);
