import '../utils/url_utils.dart';

/// 用户性别枚举
enum Gender { male, female, unknown }

/// 用户模型（对齐 OpenAPI `components.schemas.用户`）
class User {
  final String id;
  final String username;
  final String? email;
  final String? avatarUrl;
  final String? profileBackgroundImageUrl;
  final String? name;
  final String? bio;
  final Gender gender;
  final String? birthday; // YYYY-MM-DD
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;

  const User({
    required this.id,
    required this.username,
    this.email,
    this.avatarUrl,
    this.profileBackgroundImageUrl,
    this.name,
    this.bio,
    this.gender = Gender.unknown,
    this.birthday,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? avatarUrl,
    String? profileBackgroundImageUrl,
    String? name,
    String? bio,
    Gender? gender,
    String? birthday,
    String? createdAt,
    String? updatedAt,
    String? deletedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      profileBackgroundImageUrl: profileBackgroundImageUrl ?? this.profileBackgroundImageUrl,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  factory User.fromJson(Map<String, dynamic> j) {
    final dynamic rawGender = j['gender'];
    Gender genderParsed;
    if (rawGender == null) {
      genderParsed = Gender.unknown;
    } else if (rawGender is num) {
      final g = rawGender.toInt();
      genderParsed = g == 1
          ? Gender.male
          : g == 2
          ? Gender.female
          : Gender.unknown;
    } else {
      final g = rawGender.toString();
      genderParsed = g == 'male'
          ? Gender.male
          : g == 'female'
          ? Gender.female
          : Gender.unknown;
    }


    // 后端字段兼容：avatar/avatar_url，backgroundUrl/background_url/profile_background_image_url，bio/signature
    String? avatar = (j['avatar'] ?? j['avatar_url']) as String?;
    String? background = (j['backgroundUrl'] ?? j['background_url'] ?? j['profile_background_image_url']) as String?;


    if (avatar != null && avatar.isNotEmpty) {
      avatar = UrlUtils.resolveStorageUrl(avatar, defaultDir: 'avatars');
      print('🔄 转换头像URL为: $avatar');
    }

    if (background != null && background.isNotEmpty) {
      background = UrlUtils.resolveStorageUrl(background, defaultDir: 'avatars');
      print('🔄 转换背景URL为: $background');
    }


    final String? signature = j['signature'] as String?;
    final String? bio = (j['signature'] as String?) ?? signature;

    return User(
      id: (j['user_id'] ?? '').toString(),
      username: (j['username'] ?? '').toString(),
      email: j['email'] as String?,
      avatarUrl: avatar,
      profileBackgroundImageUrl: background,
      name: j['name'] as String?,
      bio: bio,
      gender: genderParsed,
      birthday: j['birthday'] as String?,
      createdAt: j['created_at'] as String?,
      updatedAt: j['updated_at'] as String?,
      deletedAt: j['deleted_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    if (email != null) 'email': email,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
    if (profileBackgroundImageUrl != null) 'profile_background_image_url': profileBackgroundImageUrl,
    if (name != null) 'name': name,
    if (bio != null) 'bio': bio,
    // 默认序列化为字符串协议，仓库会在更新时转换为数值协议（1/2/0）
    'gender': switch (gender) { Gender.male => 'male', Gender.female => 'female', _ => 'unknown' },
    if (birthday != null) 'birthday': birthday,
    if (createdAt != null) 'created_at': createdAt,
    if (updatedAt != null) 'updated_at': updatedAt,
    if (deletedAt != null) 'deleted_at': deletedAt,
  };

}

/// 资料更新请求模型（与`PUT user/info`对齐）
class UserUpdateRequest {
  final String? username;
  final String? signature; // 与 bio 等价
  final int? gender; // 1=男,2=女,0/空=不显示
  final String? birthday; // YYYY-MM-DD
  final String? avatarUrl;
  final String? backgroundUrl;

  const UserUpdateRequest({
    this.username,
    this.signature,
    this.gender,
    this.birthday,
    this.avatarUrl,
    this.backgroundUrl,
  });

  Map<String, dynamic> toQuery() {
    final m = <String, dynamic>{};
    if (username != null) m['username'] = username;
    if (signature != null) m['signature'] = signature;
    if (gender != null) m['gender'] = gender;
    if (birthday != null) m['birthday'] = birthday;
    if (avatarUrl != null) m['avatar'] = avatarUrl;
    if (backgroundUrl != null) m['backgroundUrl'] = backgroundUrl;
    return m;
  }
}

/// 基础响应状态
class BaseStatus {
  final int code;
  final String msg;
  const BaseStatus({required this.code, required this.msg});
  factory BaseStatus.fromJson(Map<String, dynamic> j) => BaseStatus(
    code: (j['code'] is int)
        ? j['code'] as int
        : int.tryParse(j['code']?.toString() ?? '0') ?? 0,
    msg: (j['message'] ?? j['msg'] ?? '').toString(),
  );
}

/// 用户响应（包含基础状态与用户数据）
class UserResponse {
  final BaseStatus base;
  final User data;
  const UserResponse({required this.base, required this.data});
  factory UserResponse.fromJson(Map<String, dynamic> j) => UserResponse(
    base: BaseStatus.fromJson(j),
    data: User.fromJson(j['data'] as Map<String, dynamic>),
  );
}
