import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme_tokens.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 自动聚焦搜索框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleSearch() {
    String query = _searchController.text.trim();
    if (query.isNotEmpty) {
      // 导航到搜索结果页面，并传递关键词参数
      context.push('/search/results?keywords=$query');
    }
  }

  void _handleBack() {
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部搜索栏
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
              ),
              child: Row(
                children: [
                  // 返回按钮
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _handleBack,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: Spacing.sm),
                  // 搜索输入框
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: Spacing.sm,
                            ),
                            child: Icon(
                              Icons.search,
                              size: 18,
                              color: Color(0xFF999999),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              decoration: const InputDecoration(
                                hintText: '搜索视频、用户或话题',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF999999),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: const TextStyle(fontSize: 14),
                              onSubmitted: (_) => _handleSearch(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 搜索按钮
                  Padding(
                    padding: const EdgeInsets.only(left: Spacing.sm),
                    child: TextButton(
                      onPressed: _handleSearch,
                      child: const Text(
                        '搜索',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 搜索历史区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(Spacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '搜索历史',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // 清除搜索历史
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('搜索历史已清除'),
                                duration: Duration(milliseconds: 1200),
                              ),
                            );
                          },
                          child: const Text(
                            '清除',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF999999),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 搜索历史内容区域 - 目前为空
                  const Expanded(
                    child: Center(
                      child: Text(
                        '暂无搜索历史',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
