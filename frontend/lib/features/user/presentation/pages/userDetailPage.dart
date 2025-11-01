import 'package:frontend/shared/styles/style.dart';
import 'package:frontend/shared/widgets/tilTokAppBar.dart';
import 'package:flutter/material.dart';

class UserDetailPage extends StatefulWidget {
  const UserDetailPage({super.key});

  @override
  _UserDetailPageState createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  @override
  Widget build(BuildContext context) {
    Widget head = const TikTokAppbar(
      title: '用户',
    );
    var userHead = Row(
      children: <Widget>[
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            child: const Text(
              '个人信息',
              style: StandardTextStyle.smallWithOpacity,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: Text(
            '修改',
            style: StandardTextStyle.smallWithOpacity.apply(
              color: ColorPlate.orange,
            ),
          ),
        )
      ],
    );
    Widget body = ListView(
      padding: EdgeInsets.only(
        bottom: 80 + MediaQuery.of(context).padding.bottom,
      ),
      children: <Widget>[
        userHead,
        _UserInfoRow(
          title: '昵称',
          rightIcon: const Text(
            '朱二蛋的枯燥生活',
            style: StandardTextStyle.small,
          ),
        ),
        _UserInfoRow(
          title: '头像',
          rightIcon: const Text(
            '上传',
            style: StandardTextStyle.small,
          ),
        ),
        _UserInfoRow(
          title: '手机绑定',
          rightIcon: const Text(
            '186****7767',
            style: StandardTextStyle.small,
          ),
        ),
        _UserInfoRow(
          title: '地址',
          rightIcon: const Text(
            '深圳市南山区南海大道',
            style: StandardTextStyle.small,
          ),
        ),
        _UserInfoRow(
          title: '年龄',
          rightIcon: const Text(
            '18',
            style: StandardTextStyle.small,
          ),
        ),
        _UserInfoRow(
          title: '用户性别',
          rightIcon: const Text(
            '男',
            style: StandardTextStyle.small,
          ),
        ),
        _UserInfoRow(
          title: '职业',
          rightIcon: const Text(
            '总裁',
            style: StandardTextStyle.small,
          ),
        ),
      ],
    );
    body = Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: body,
      ),
    );
    return Scaffold(
      body: Container(
        color: ColorPlate.back1,
        height: double.infinity,
        width: double.infinity,
        child: Column(
          children: <Widget>[
            head,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _UserInfoRow extends StatelessWidget {
  const _UserInfoRow({
    this.title,
    this.rightIcon,
    this.icon,
    this.onTap,
  });

  final Widget? icon;
  final Widget? rightIcon;
  final String? title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget iconImg = SizedBox(
      height: 24,
      width: 24,
      child: icon,
    );

    Widget row = Container(
      height: 48,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: const Border(
          bottom: BorderSide(color: Colors.white12),
        ),
      ),
      child: Row(
        children: <Widget>[
          icon != null ? iconImg : Container(),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                title!,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          Opacity(
            opacity: 0.6,
            child: rightIcon ??
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                ),
          ),
        ],
      ),
    );
    row = GestureDetector(
      onTap: onTap,
      child: row,
    );

    return row;
  }
}
