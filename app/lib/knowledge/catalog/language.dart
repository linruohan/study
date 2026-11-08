import 'package:flutter/material.dart';

import '../age_band.dart';
import '../concept.dart';
import '../domain.dart';

/// 语领域：从认字到读懂公共文本，同一概念在不同年龄只换呈现深度。
const languageDomain = LearningDomain(
  id: 'language',
  name: '语',
  glyph: '字',
  color: Color(0xFF8C4A2F),
  concepts: [
    Concept(
      id: 'zi_ri',
      domainId: 'language',
      depth: 0,
      variants: {
        AgeBand.toddler: ConceptVariant(
          topic: '认一认「日」',
          glyph: '日',
          doing: '指出太阳是「日」',
          praise: '你能指出太阳是「日」',
          check: '窗边的太阳和纸上的太阳，都是「日」吗？',
          answer: '都是。同一个字可以在不同地方认出来。',
          note: '先看窗外的太阳，再指纸上的字。',
        ),
        AgeBand.lowerPrimary: ConceptVariant(
          topic: '用「日」写一句话',
          glyph: '日',
          doing: '说一句带「日」的话，例如「今天有太阳」',
          praise: '你能用「日」说一句话',
          check: '「日」在这句里是太阳，还是日子？',
          answer: '两种意思都有，要看句子在说哪一天。',
          note: '写完读给身边的人听。',
        ),
        AgeBand.upperPrimary: ConceptVariant(
          topic: '从一段里读出「日」',
          glyph: '日',
          doing: '读一段短文，标出写太阳的句子',
          praise: '你能在一段里找出写太阳的句子',
          check: '哪一句在写光和热？',
          answer: '写光亮和温度的那一句。',
          note: '不确定时，先把写光亮的词圈出来。',
        ),
      },
    ),
    Concept(
      id: 'read_notice',
      domainId: 'language',
      depth: 1,
      prerequisites: ['zi_ri'],
      variants: {
        AgeBand.lowerPrimary: ConceptVariant(
          topic: '读懂一则校园通知',
          doing: '在通知里找到时间和地点',
          praise: '你能找到通知里的时间和地点',
          check: '通知要你什么时候到哪里？',
          answer: '时间和地点各有一处。',
          note: '先找冒号后面那两样。',
        ),
        AgeBand.upperPrimary: ConceptVariant(
          topic: '找出通知要带的材料',
          doing: '在通知里圈出需要带的东西',
          praise: '你能在通知里找齐要带的东西',
          check: '如果漏了一样，会发生什么？',
          answer: '可能办不成，需要回去拿。',
        ),
        AgeBand.middleSchool: ConceptVariant(
          topic: '读出通知里的条件',
          doing: '写出这则通知的适用对象和截止时间',
          praise: '你能写出通知的条件',
          check: '谁需要办，办到什么时候？',
          answer: '适用对象和截止时间各一句。',
          note: '条件常写在「凡」「须」「前」这些词附近。',
        ),
        AgeBand.beyondSchool: ConceptVariant(
          topic: '读懂一则公共通告',
          doing: '标出事项、时间、地点和咨询方式',
          praise: '你能把公共通告的要素找到',
          check: '这条通告让人做什么？',
          answer: '先看动词，再看时间和地点。',
          note: '找不到咨询方式时，写下缺的那一项。',
        ),
      },
    ),
    Concept(
      id: 'own_note',
      domainId: 'language',
      depth: 2,
      prerequisites: ['read_notice'],
      variants: {
        AgeBand.upperPrimary: ConceptVariant(
          topic: '写一句自己的看法',
          doing: '写一句你为什么这么想',
          praise: '你能写出自己的看法和理由',
          check: '你的理由来自看到的哪一处？',
          answer: '说出具体的一处，不是只说「我觉得」。',
        ),
        AgeBand.middleSchool: ConceptVariant(
          topic: '写一段有出处的笔记',
          doing: '摘一句原文，并写下它出自哪里',
          praise: '你能写出带出处的笔记',
          check: '这句话你能在哪里再找到？',
          answer: '写清书名、页码或链接。',
          note: '转述不能代替原句。',
        ),
        AgeBand.highSchool: ConceptVariant(
          topic: '写出结论依赖的条件',
          doing: '给你的结论补一句「在什么条件下成立」',
          praise: '你能写出结论成立的条件',
          check: '换一个条件，结论还成立吗？',
          answer: '把条件写在结论旁边，再试着换掉它。',
        ),
        AgeBand.college: ConceptVariant(
          topic: '文献摘录和出处',
          doing: '摘一段文献，标出作者、年份和页码',
          praise: '你能写出可复核的文献摘录',
          check: '别人照这条信息能找到原文吗？',
          answer: '作者、年份、页码各一处。',
        ),
        AgeBand.beyondSchool: ConceptVariant(
          topic: '记一条只给自己的反思',
          doing: '写一句今天更知道自己什么',
          praise: '你能写一句只给自己的反思',
          check: '这句不用给别人看，也不用打分。',
          answer: '留给自己就好。',
          note: '只存在本机，可随时删。',
        ),
      },
    ),
  ],
);
