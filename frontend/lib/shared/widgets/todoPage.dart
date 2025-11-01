import 'package:frontend/shared/styles/style.dart';
import 'package:flutter/material.dart';

class TodoPage extends StatelessWidget {
  final String? title;
  final String? detail;

  const TodoPage({
    super.key,
    this.title,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    bool canpop = Navigator.of(context).canPop();
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
                  child: const FlutterLogo(
                    size: 120,
                  ),
                ),
                Text(
                  title ?? '未开放的页面',
                  style: StandardTextStyle.big,
                ),
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  child: Text(
                    detail ?? '正在施工中',
                    style: StandardTextStyle.smallWithOpacity,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: canpop
                  ? GestureDetector(
                      child: const Icon(
                        Icons.clear,
                        size: 30,
                        color: Colors.red,
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                    )
                  : Container(),
            ),
          ),
          const Expanded(
            child: Center(),
          ),
        ],
      ),
    );
  }
}
