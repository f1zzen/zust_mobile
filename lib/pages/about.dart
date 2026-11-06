import 'package:flutter/material.dart';
import '../info.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// Новости, спонсоры, сообщество - шторка с вкладками.
Future<void> showAbout(BuildContext context, int tab) async {
  final t = ZThemeScope.of(context);
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.classic ? const Color(0xFF0E0718) : t.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusL))),
    builder: (_) => ZThemeScope(theme: t, child: _About(tab)),
  );
  if (info.newsId.isNotEmpty) prefs.setNewsSeen(info.newsId);
}

class _About extends StatefulWidget {
  final int tab;
  const _About(this.tab);

  @override
  State<_About> createState() => _AboutState();
}

class _AboutState extends State<_About> {
  late int tab = widget.tab;

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    final title = [info.newsTitle.isEmpty ? 'Новости' : info.newsTitle, 'Спонсоры на Boosty', 'Наше сообщество'][tab];
    final hint = [
      '',
      'Люди, которые поддержали Z.UST деньгами. Список пополняется с каждой версией.',
      'Люди, которые помогли Z.UST или сделали для него что-то важное.',
    ][tab];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      maxChildSize: .95,
      builder: (context, scroll) => ListenableBuilder(
        listenable: info,
        builder: (context, _) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              t.t(title),
              style: TextStyle(fontFamily: t.headingFont, fontSize: 22, fontWeight: t.headingWeight, color: t.onSurface),
            ),
            if (hint.isNotEmpty) ...[const SizedBox(height: 4), Text(hint, style: TextStyle(fontSize: 13, color: t.onSurfaceVariant))],
            const SizedBox(height: 14),
            Segmented(items: const ['Новости', 'Спонсоры', 'Сообщество'], selected: tab, onChanged: (i) => setState(() => tab = i)),
            const SizedBox(height: 16),
            if (tab == 0)
              Text(
                info.newsBody.isEmpty ? 'Новостей пока нет. Следите за ТГК!' : info.newsBody,
                style: TextStyle(fontSize: 15, height: 1.4, color: t.onSurface),
              )
            else
              _Grid(tab == 1 ? info.sponsors : info.community),
            const SizedBox(height: 20),
            tab == 1
                ? ZButton(
                    'Поддержать',
                    icon: Icons.favorite_rounded,
                    kind: BtnKind.tonal,
                    expand: true,
                    onTap: () => zust.openLink('https://boosty.to/zust'),
                  )
                : ZButton(
                    'Телеграм-канал',
                    icon: Icons.send_rounded,
                    kind: BtnKind.tonal,
                    expand: true,
                    onTap: () => zust.openLink('https://t.me/zdotust'),
                  ),
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  final List<Person> people;
  const _Grid(this.people);

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: [
        for (final p in people)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: t.classic ? Colors.white.withValues(alpha: .04) : t.surfaceHigh,
              borderRadius: BorderRadius.circular(t.radiusM),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.onSurface),
                ),
                if (p.note.isNotEmpty)
                  Text(
                    p.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.primary),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
