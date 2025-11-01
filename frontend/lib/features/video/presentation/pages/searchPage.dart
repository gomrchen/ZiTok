import 'package:frontend/shared/styles/style.dart';
import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  final VoidCallback? onPop;

  const SearchPage({
    super.key,
    this.onPop,
  });

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  @override
  Widget build(BuildContext context) {
    Widget head = Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      color: ColorPlate.back2,
      width: double.infinity,
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.fullscreen,
              size: 24,
            ),
            Expanded(
              child: Container(
                height: 32,
                margin: const EdgeInsets.only(right: 20, left: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.only(left: 12),
                child: Opacity(
                  opacity: 0.3,
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.search,
                        size: 20,
                      ),
                      Container(
                        padding: const EdgeInsets.only(left: 2, bottom: 2),
                        child: const Text(
                          '搜索内容',
                          style: StandardTextStyle.normal,
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: widget.onPop,
              child: Text(
                '取消',
                style: StandardTextStyle.normal.apply(color: ColorPlate.orange),
              ),
            ),
          ],
        ),
      ),
    );
    Widget body = ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        const _SearchSelectRow(),
        const _SearchSelectRow(),
        const _SearchSelectRow(),
        const _SearchSelectRow(),
        const _SearchSelectRow(),
        Opacity(
          opacity: 0.6,
          child: SizedBox(
            height: 46,
            child: const Center(child: Text('全部搜索记录')),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: AspectRatio(
            aspectRatio: 4.0,
            child: Container(
              decoration: BoxDecoration(
                color: ColorPlate.darkGray,
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '预留轮播图',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.1),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
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

class _SearchSelectRow extends StatelessWidget {
  const _SearchSelectRow({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.timelapse,
            size: 20,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 8, bottom: 1),
              child: const Text(
                '搜索热点',
                style: StandardTextStyle.normal,
              ),
            ),
          ),
          const Icon(
            Icons.clear,
            size: 20,
          ),
        ],
      ),
    );
  }
}
