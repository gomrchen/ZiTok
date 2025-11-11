class UserInfo {
  final String id;
  final String userName;
  final String? email;
  final int? gender; // 0/1
  final String? avatar;
  final int? fans;
  final int? follows;
  final int? createAt;
  final int? updateAt;
  final bool? totpStatus;

  const UserInfo({
    required this.id,
    required this.userName,
    this.email,
    this.gender,
    this.avatar,
    this.fans,
    this.follows,
    this.createAt,
    this.updateAt,
    this.totpStatus,
  });

  factory UserInfo.fromJson(Map<String, dynamic> j) => UserInfo(
        id: (j['id'] ?? '').toString(),
        userName: (j['username'] ?? '').toString(),
        email: j['email'] as String?,
        gender: j['gender'] is int ? j['gender'] as int : int.tryParse('${j['gender']}'),
        avatar: j['avatar'] as String?,
        fans: j['fans'] is int ? j['fans'] as int : int.tryParse('${j['fans']}'),
        follows: j['follows'] is int ? j['follows'] as int : int.tryParse('${j['follows']}'),
        createAt: j['create_at'] as int?,
        updateAt: j['update_at'] as int?,
        totpStatus: j['totp_status'] as bool?,
      );
}

class RelationList {
  final int count;
  final List<UserInfo> items;
  const RelationList({required this.count, required this.items});
  factory RelationList.fromJson(Map<String, dynamic> j) => RelationList(
        count: j['count'] is int ? j['count'] as int : int.tryParse('${j['count']}') ?? 0,
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => UserInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
