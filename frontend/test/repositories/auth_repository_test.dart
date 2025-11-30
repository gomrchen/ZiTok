import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitok/repositories/auth_repository.dart';
import 'package:zitok/services/auth_service.dart';
import 'package:zitok/services/api_client.dart';
import 'package:zitok/services/user_session.dart';
import 'package:dio/dio.dart';

class FakeAuthService extends AuthService {
  FakeAuthService(super.client, {required super.prefs});

  @override
  Future<Response> login({required String username, required String password}) {
    return Future.value(
      Response(
        requestOptions: RequestOptions(path: '/user/login'),
        data: {
          'base': {'code': 10000, 'msg': 'success'},
          'data': {
            'id': '1',
            'username': username,
            'avatar_url': '',
            'name': 'n',
            'bio': '',
            'gender': 'unknown',
            'birthday': '1990-01-01',
            'created_at': '1970-01-01 08:00:00',
            'updated_at': '1970-01-01 08:00:00',
            'deleted_at': '1970-01-01 08:00:00',
          },
        },
      ),
    );
  }

  @override
  Future<Response> register({
    required String username,
    required String email,
    required String password,
    required String verificationCode,
  }) {
    return Future.value(
      Response(
        requestOptions: RequestOptions(path: '/user/register'),
        data: {
          'base': {'code': 10000, 'msg': 'success'},
          'data': {
            'id': '2',
            'username': username,
            'email': email,
            'avatar_url': '',
            'name': 'n',
            'bio': '',
            'gender': 'unknown',
            'birthday': '1990-01-01',
            'created_at': '1970-01-01 08:00:00',
            'updated_at': '1970-01-01 08:00:00',
            'deleted_at': '1970-01-01 08:00:00',
          },
        },
      ),
    );
  }

  @override
  Future<Response> profile() {
    return Future.value(
      Response(
        requestOptions: RequestOptions(path: '/user/info'),
        data: {
          'base': {'code': 10000, 'msg': 'success'},
          'data': {
            'id': '1',
            'username': 'u',
            'avatar_url': '',
            'name': 'n',
            'bio': '',
            'gender': 'unknown',
            'birthday': '1990-01-01',
            'created_at': '1970-01-01 08:00:00',
            'updated_at': '1970-01-01 08:00:00',
            'deleted_at': '1970-01-01 08:00:00',
          },
        },
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('AuthRepository', () {
    late SharedPreferences prefs;
    late AuthRepository repo;
    late UserSession userSession;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      // 重置并获取 UserSession 实例
      UserSession.resetInstance();
      userSession = UserSession.instance;

      final client = ApiClient(baseUrl: 'http://example', prefs: prefs);
      repo = AuthRepository(
        authService: FakeAuthService(client, prefs: prefs),
        prefs: prefs,
        userSession: userSession,
      );
    });

    test('login returns User and persists id', () async {
      final user = await repo.login(username: 'u', password: 'p');
      expect(user.username, 'u');
      expect(prefs.getString('user_id'), '1');
      expect(userSession.userId, '1');
    });

    test('register returns User and persists id', () async {
      final user = await repo.register(
        username: 'u2',
        email: 'e@example.com',
        password: 'p',
        verificationCode: '123456',
      );
      expect(user.username, 'u2');
      expect(prefs.getString('user_id'), '2');
      expect(userSession.userId, '2');
    });
  });
}
