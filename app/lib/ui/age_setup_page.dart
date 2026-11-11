import 'package:flutter/material.dart';

import '../app_brand.dart';
import '../knowledge/age_band.dart';
import '../profile/local_profile.dart';
import 'theme.dart';
import 'widgets/glyph_badge.dart';

/// 年龄档选择页：打开应用先确认年龄。
///
/// 换档时换目录，交接的是已经会的能力；这里只保存档位，不改档案。
class AgeSetupPage extends StatefulWidget {
  const AgeSetupPage({
    super.key,
    required this.store,
    required this.onChosen,
  });

  final LocalProfile store;
  final ValueChanged<AgeBand> onChosen;

  @override
  State<AgeSetupPage> createState() => _AgeSetupPageState();
}

class _AgeSetupPageState extends State<AgeSetupPage> {
  var _busy = false;

  /// 选中一档后保存，再把选择交给调用方决定下一步去哪。
  Future<void> _choose(AgeBand band) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    await widget.store.save(StudyProfile(band: band));
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    widget.onChosen(band);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${AppBrand.name} · ${AppBrand.englishName}'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text('你现在在哪一档', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            Text(AppBrand.slogan, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(
              '换档时换目录。已经会的可以跳到后面的目录，不会因为换档消失。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            for (final band in AgeBand.values) ...[
              PaperCard(
                key: Key('band_${band.id}'),
                onTap: _busy ? null : () => _choose(band),
                child: Row(
                  children: [
                    GlyphBadge(
                      icon: _bandIcon(band),
                      color: paperOchre,
                      size: 44,
                      fontSize: 22,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            band.label,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            band.howToLearn,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: paperInkSoft),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// 每个年龄档用一个简图标，幼儿档不依赖文字也能认出来。
IconData _bandIcon(AgeBand band) {
  return switch (band) {
    AgeBand.toddler => Icons.child_care_outlined,
    AgeBand.lowerPrimary => Icons.auto_stories_outlined,
    AgeBand.upperPrimary => Icons.edit_outlined,
    AgeBand.middleSchool => Icons.science_outlined,
    AgeBand.highSchool => Icons.lightbulb_outline,
    AgeBand.college => Icons.school_outlined,
    AgeBand.beyondSchool => Icons.work_outline,
  };
}
