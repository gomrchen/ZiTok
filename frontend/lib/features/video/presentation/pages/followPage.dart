import 'package:frontend/shared/styles/style.dart';
import 'package:frontend/shared/widgets/tikTokCommentBottomSheet.dart';
import 'package:frontend/shared/widgets/tikTokVideo.dart';
import 'package:frontend/shared/widgets/tilTokAppBar.dart';
import 'package:frontend/shared/utils/safe_map.dart';
import 'package:frontend/shared/utils/custom_bottom_sheet.dart';
import 'package:flutter/material.dart';

class FollowPage extends StatefulWidget {
  const FollowPage({super.key});

  @override
  _FollowPageState createState() => _FollowPageState();
}

class _FollowPageState extends State<FollowPage> {
  Map<int, bool> fMap = {};
  int select = 0;

  @override
  Widget build(BuildContext context) {
    Widget head = TikTokSwitchAppbar(
      index: select,
      list: const ['推荐', '关注'],
      onSwitch: (i) => setState(() => select = i),
    );
    Widget body = ListView.builder(
      padding: EdgeInsets.only(
        bottom: 80 + MediaQuery.of(context).padding.bottom,
      ),
      itemCount: 10,
      itemBuilder: (ctx, i) {
        bool isF = SafeMap(fMap)[i].boolean;
        return FollowRow(
          isFavorite: isF,
          onFavorite: () {
            setState(() {
              fMap[i] = !isF;
            });
          },
          onAddFavorite: () {
            setState(() {
              fMap[i] = true;
            });
          },
          onComment: () {
            CustomBottomSheet.showModalBottomSheet(
              backgroundColor: Colors.white.withOpacity(0),
              context: context,
              builder: (BuildContext context) => const TikTokCommentBottomSheet(),
            );
          },
          onShare: () {},
        );
      },
    );
    return Container(
      color: ColorPlate.back1,
      height: double.infinity,
      width: double.infinity,
      child: Column(
        children: <Widget>[
          head,
          Expanded(child: body),
        ],
      ),
    );
  }
}

class FollowRow extends StatelessWidget {
  final bool? isFavorite;
  final VoidCallback? onFavorite;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onAddFavorite;

  const FollowRow({
    super.key,
    this.isFavorite,
    this.onFavorite,
    this.onComment,
    this.onShare,
    this.onAddFavorite,
  });

  @override
  Widget build(BuildContext context) {
    Widget video = TikTokVideoPage(
      // rightButtonColumn= true,
      aspectRatio: 6.0 / 9,
      onAddFavorite: onAddFavorite,
      userInfoWidget: Container(),
    );
    video = Container(
      alignment: Alignment.topLeft,
      height: 400,
      child: AspectRatio(
        aspectRatio: 6.0 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: video,
        ),
      ),
    );
    Widget userInfo = Row(
      children: <Widget>[
        SizedBox(
          height: 32,
          width: 32,
          child: ClipOval(
            child: Image.network(
              "https://wpimg.wallstcn.com/f778738c-e4f8-4870-b634-56703b4acafe.gif",
              fit: BoxFit.cover,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Text(
            '朱二蛋的枯燥生活',
            style: StandardTextStyle.normalW,
          ),
        )
      ],
    );
    Widget content = const Padding(
      padding: EdgeInsets.fromLTRB(2, 6, 50, 8),
      child: Text(
        '#原创 有钱人的生活就是这么朴实无华，且枯燥 #短视频',
        style: StandardTextStyle.normal,
      ),
    );
    var buttonRow = Row(
      children: <Widget>[
        const Text(
          '10-9',
          style: StandardTextStyle.smallWithOpacity,
        ),
        Expanded(child: Container()),
        const _RowButton(
          iconData: Icons.share,
          title: '分享',
        ),
        _RowButton(
          iconData: Icons.mode_comment,
          size: SysSize.iconNormal - 2,
          title: '评论',
          onTap: onComment,
        ),
        _RowButton(
          color: isFavorite! ? ColorPlate.red : null,
          iconData: Icons.favorite,
          title: '赞',
          onTap: onFavorite,
        ),
      ],
    );
    return Container(
      // color: Colors.red,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.05),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          userInfo,
          content,
          video,
          Opacity(
            opacity: 0.8,
            child: Container(
              padding: const EdgeInsets.fromLTRB(0, 10, 12, 8),
              child: buttonRow,
            ),
          )
        ],
      ),
    );
  }
}

class _RowButton extends StatelessWidget {
  final IconData? iconData;
  final Color? color;
  final double? size;
  final String? title;
  final VoidCallback? onTap;

  const _RowButton({
    super.key,
    this.iconData,
    this.size,
    this.title,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Row(
          children: <Widget>[
            Icon(
              iconData ?? Icons.favorite,
              size: size ?? SysSize.iconNormal,
              color: color,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                title ?? '??',
                style: StandardTextStyle.small,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
