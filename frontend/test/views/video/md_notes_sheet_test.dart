import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zitok/views/video/widgets/md_notes_sheet.dart';

void main() {
  testWidgets('MdNotesBottomSheet opens, scrolls and closes', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const MdNotesBottomSheet(videoId: 'vid001'),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ));

    // 打开弹窗
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('关联笔记'), findsOneWidget);

    // 可滚动
    final listFinder = find.byType(ListView);
    if (listFinder.evaluate().isNotEmpty) {
      await tester.drag(listFinder, const Offset(0, -200));
      await tester.pump();
    }

    // 关闭按钮
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('关联笔记'), findsNothing);
  });
}