import 'dart:io';

Socket? socket;

/// 模拟视频数据列表
var videoList = [
  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4',
];

/// 用户视频数据模型
class UserVideo {
  final String id;
  final String url;
  final String image;
  final String? desc;
  final String authorName;
  final String authorAvatar;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool isLiked;
  final String musicName;
  final String musicAuthor;

  UserVideo({
    required this.id,
    required this.url,
    required this.image,
    this.desc,
    required this.authorName,
    required this.authorAvatar,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.isLiked = false,
    this.musicName = '原声',
    this.musicAuthor = '作者原创',
  });

  /// 获取模拟视频数据
  static List<UserVideo> fetchVideo() {
    List<UserVideo> list = [];
    
    for (int i = 0; i < videoList.length; i++) {
      list.add(UserVideo(
        id: 'video_$i',
        url: videoList[i],
        image: 'https://picsum.photos/400/600?random=$i', // 随机封面图
        desc: _getRandomDesc(i),
        authorName: _getRandomAuthor(i),
        authorAvatar: 'https://picsum.photos/100/100?random=${i + 100}',
        likeCount: _getRandomCount(1000, 50000),
        commentCount: _getRandomCount(10, 1000),
        shareCount: _getRandomCount(5, 500),
        isLiked: i % 3 == 0, // 每三个视频中有一个被点赞
        musicName: _getRandomMusic(i),
        musicAuthor: _getRandomAuthor(i),
      ));
    }
    
    return list;
  }

  /// 生成随机描述
  static String _getRandomDesc(int index) {
    List<String> descriptions = [
      '这是一个很有趣的视频 #搞笑 #日常',
      '分享生活中的美好时刻 ✨ #生活 #美好',
      '今天的心情特别好 😊 #心情 #开心',
      '和朋友们一起度过的快乐时光 #友谊 #快乐',
      '记录下这个特别的瞬间 📸 #记录 #瞬间',
      '学习新技能的过程 💪 #学习 #成长',
      '美食制作全过程 🍳 #美食 #制作',
      '旅行中的美丽风景 🌅 #旅行 #风景',
      '运动健身日常打卡 🏃‍♂️ #运动 #健身',
      '宠物的可爱瞬间 🐱 #宠物 #可爱',
    ];
    return descriptions[index % descriptions.length];
  }

  /// 生成随机作者名
  static String _getRandomAuthor(int index) {
    List<String> authors = [
      '小明同学',
      '美食达人小李',
      '旅行者小王',
      '健身教练小张',
      '摄影师小刘',
      '音乐人小陈',
      '舞蹈老师小赵',
      '学霸小孙',
      '搞笑博主小周',
      '生活家小吴',
    ];
    return authors[index % authors.length];
  }

  /// 生成随机音乐名
  static String _getRandomMusic(int index) {
    List<String> musics = [
      '夜空中最亮的星',
      '青春',
      '小幸运',
      '演员',
      '告白气球',
      '稻香',
      '晴天',
      '七里香',
      '简单爱',
      '听妈妈的话',
    ];
    return musics[index % musics.length];
  }

  /// 生成随机数量
  static int _getRandomCount(int min, int max) {
    return min + (DateTime.now().millisecondsSinceEpoch % (max - min));
  }

  @override
  String toString() {
    return 'UserVideo{id: $id, desc: $desc, author: $authorName}';
  }

  /// 转换为JSON格式
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'image': image,
      'desc': desc,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'shareCount': shareCount,
      'isLiked': isLiked,
      'musicName': musicName,
      'musicAuthor': musicAuthor,
    };
  }

  /// 从JSON创建对象
  factory UserVideo.fromJson(Map<String, dynamic> json) {
    return UserVideo(
      id: json['id'] ?? '',
      url: json['url'] ?? '',
      image: json['image'] ?? '',
      desc: json['desc'],
      authorName: json['authorName'] ?? '',
      authorAvatar: json['authorAvatar'] ?? '',
      likeCount: json['likeCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      shareCount: json['shareCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      musicName: json['musicName'] ?? '原声',
      musicAuthor: json['musicAuthor'] ?? '作者原创',
    );
  }
}