import 'package:flutter/material.dart';

import 'selectText.dart';

class TikTokHeader extends StatefulWidget {
  final VoidCallback? onSearch;

  const TikTokHeader({
    super.key,
    this.onSearch,
  });

  @override
  _TikTokHeaderState createState() => _TikTokHeaderState();
}

class _TikTokHeaderState extends State<TikTokHeader> {
  int currentSelect = 0;

  @override
  Widget build(BuildContext context) {
    List<String> list = ['混合', '竖屏'];
    List<Widget> headList = [];
    for (var i = 0; i < list.length; i++) {
      headList.add(Expanded(
        child: GestureDetector(
          child: Container(
            child: SelectText(
              title: list[i],
              isSelect: i == currentSelect,
            ),
          ),
          onTap: () {
            setState(() {
              currentSelect = i;
            });
          },
        ),
      ));
    }
    Widget headSwitch = Row(
      children: headList,
    );
    return Container(
      // color: Colors.black.withOpacity(0.3),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              onTap: widget.onSearch,
              child: Container(
                color: Colors.black.withOpacity(0),
                padding: EdgeInsets.all(4),
                alignment: Alignment.centerLeft,
                child: Icon(
                  Icons.search,
                  color: Colors.white.withOpacity(0.66),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black.withOpacity(0),
              alignment: Alignment.center,
              child: headSwitch,
            ),
          ),
          Expanded(
            child: GestureDetector(
              child: Container(
                color: Colors.black.withOpacity(0),
                padding: const EdgeInsets.all(4),
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.tv,
                  color: Colors.white.withOpacity(0.66),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
