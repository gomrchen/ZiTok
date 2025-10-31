import 'package:json_annotation/json_annotation.dart';

part 'video_model.g.dart';

/// 视频模型
@JsonSerializable()
class VideoModel {
  /// 视频ID
  final String id;
  
  /// 视频标题
  final String title;
  
  /// 视频描述
  final String? description;
  
  /// 视频URL
  @JsonKey(name: 'video_url')
  final String videoUrl;
  
  /// 封面图URL
  @JsonKey(name: 'cover_url')
  final String? coverUrl;
  
  /// 视频时长（秒）
  final int duration;
  
  /// 视频大小（字节）
  @JsonKey(name: 'file_size')
  final int fileSize;
  
  /// 视频宽度
  final int width;
  
  /// 视频高度
  final int height;
  
  /// 创建者ID
  @JsonKey(name: 'creator_id')
  final String creatorId;
  
  /// 创建者信息
  final UserModel? creator;
  
  /// 点赞数
  @JsonKey(name: 'like_count')
  final int likeCount;
  
  /// 评论数
  @JsonKey(name: 'comment_count')
  final int commentCount;
  
  /// 分享数
  @JsonKey(name: 'share_count')
  final int shareCount;
  
  /// 观看数
  @JsonKey(name: 'view_count')
  final int viewCount;
  
  /// 是否已点赞
  @JsonKey(name: 'is_liked')
  final bool isLiked;
  
  /// 是否已收藏
  @JsonKey(name: 'is_favorited')
  final bool isFavorited;
  
  /// 标签列表
  final List<String> tags;
  
  /// 知识点列表
  @JsonKey(name: 'knowledge_points')
  final List<String> knowledgePoints;
  
  /// 创建时间
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  
  /// 更新时间
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  
  const VideoModel({
    required this.id,
    required this.title,
    this.description,
    required this.videoUrl,
    this.coverUrl,
    required this.duration,
    required this.fileSize,
    required this.width,
    required this.height,
    required this.creatorId,
    this.creator,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.viewCount,
    required this.isLiked,
    required this.isFavorited,
    required this.tags,
    required this.knowledgePoints,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory VideoModel.fromJson(Map<String, dynamic> json) =>
      _$VideoModelFromJson(json);
  
  Map<String, dynamic> toJson() => _$VideoModelToJson(this);
  
  /// 复制并更新
  VideoModel copyWith({
    String? id,
    String? title,
    String? description,
    String? videoUrl,
    String? coverUrl,
    int? duration,
    int? fileSize,
    int? width,
    int? height,
    String? creatorId,
    UserModel? creator,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    int? viewCount,
    bool? isLiked,
    bool? isFavorited,
    List<String>? tags,
    List<String>? knowledgePoints,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VideoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      width: width ?? this.width,
      height: height ?? this.height,
      creatorId: creatorId ?? this.creatorId,
      creator: creator ?? this.creator,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      viewCount: viewCount ?? this.viewCount,
      isLiked: isLiked ?? this.isLiked,
      isFavorited: isFavorited ?? this.isFavorited,
      tags: tags ?? this.tags,
      knowledgePoints: knowledgePoints ?? this.knowledgePoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is VideoModel && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() {
    return 'VideoModel{id: $id, title: $title, creatorId: $creatorId}';
  }
}

/// 用户模型（简化版）
@JsonSerializable()
class UserModel {
  final String id;
  final String username;
  final String? nickname;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  final bool verified;
  
  const UserModel({
    required this.id,
    required this.username,
    this.nickname,
    this.avatarUrl,
    required this.verified,
  });
  
  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
  
  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}