import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:zitok/views/profile/edit_profile_page.dart';
import 'package:zitok/services/user_service.dart';

void main() {
  group('EditProfilePage basic rendering', () {
    testWidgets('shows header controls and completion bar', (tester) async {
      // Prepare Hive boxes used by the page
      final tempDir = await Directory.systemTemp.createTemp('zitok_test');
      Hive.init(tempDir.path);
      await Hive.openBox('user_box');
      addTearDown(() async {
        await Hive.box('user_box').close();
        await Hive.deleteBoxFromDisk('user_box');
        await tempDir.delete(recursive: true);
      });

      final fakeService = UserService(Dio(BaseOptions(baseUrl: 'http://localhost')));
      await tester.pumpWidget(
        MaterialApp(
          home: EditProfilePage(userService: fakeService),
        ),
      );
      await tester.pump();

      expect(find.text('更换封面'), findsOneWidget);
      expect(find.text('资料完成度'), findsOneWidget);
      // Avatar placeholder or image should be present
      expect(find.byType(CircleAvatar), findsWidgets);
    });
  });
}