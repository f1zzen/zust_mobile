import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../theme.dart';

void showLogs(BuildContext context) {
  final t = ZThemeScope.of(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.classic ? const Color(0xFF0E0718) : t.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusL))),
    builder: (_) => ZThemeScope(
      theme: t,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        maxChildSize: .95,
        builder: (context, scroll) => ListenableBuilder(
          listenable: zust,
          builder: (context, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.t('Журнал'),
                        style: TextStyle(fontFamily: t.headingFont, fontSize: 20, fontWeight: t.headingWeight, color: t.onSurface),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Скопировать',
                      icon: Icon(Icons.copy_rounded, color: t.onSurfaceVariant),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: zust.logs.join('\n')));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Журнал скопирован')));
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: zust.logs.isEmpty
                    ? Center(
                        child: Text('Пока пусто', style: TextStyle(color: t.onSurfaceVariant)),
                      )
                    : ListView.builder(
                        controller: scroll,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: zust.logs.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            zust.logs[zust.logs.length - 1 - i],
                            style: TextStyle(fontFamily: 'IBMPlexMono', fontSize: 11.5, color: t.onSurfaceVariant, height: 1.35),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
