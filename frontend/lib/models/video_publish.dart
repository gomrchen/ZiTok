/// 视频投稿请求模型
class VideoPublishRequest {
  final String filePath;
  final String title;
  final String description;
  final String userId;
  final List<String> tags;

  const VideoPublishRequest({
    required this.filePath,
    required this.title,
    required this.description,
    required this.userId,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'user_id': userId,
        'tags': tags,
      };
}

/// 视频投稿响应模型
class VideoPublishResponse {
  final String code;
  final String message;
  final String? videoId;

  const VideoPublishResponse({
    required this.code,
    required this.message,
    this.videoId,
  });

  factory VideoPublishResponse.fromJson(Map<String, dynamic> json) {
    return VideoPublishResponse(
      code: (json['code'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      videoId: json['video_id']?.toString() ?? json['data']?['video_id']?.toString(),
    );
  }

  bool get isSuccess => code == '10000';
}

/// 视频投稿状态枚举
enum PublishStatus {
  idle,
  selecting,
  uploading,
  processing,
  success,
  failed,
}

/// 视频投稿进度模型
class PublishProgress {
  final PublishStatus status;
  final double progress;
  final String? message;
  final String? errorMessage;

  const PublishProgress({
    required this.status,
    this.progress = 0.0,
    this.message,
    this.errorMessage,
  });

  factory PublishProgress.idle() => const PublishProgress(status: PublishStatus.idle);

  factory PublishProgress.selecting() =>
      const PublishProgress(status: PublishStatus.selecting, message: '选择视频文件...');

  factory PublishProgress.uploading(double progress) => PublishProgress(
        status: PublishStatus.uploading,
        progress: progress,
        message: '上传中 ${(progress * 100).toStringAsFixed(1)}%',
      );

  factory PublishProgress.processing() =>
      const PublishProgress(status: PublishStatus.processing, message: '处理中...');

  factory PublishProgress.success() =>
      const PublishProgress(status: PublishStatus.success, progress: 1.0, message: '发布成功');

  factory PublishProgress.failed(String error) => PublishProgress(
        status: PublishStatus.failed,
        errorMessage: error,
        message: '发布失败',
      );

  bool get isIdle => status == PublishStatus.idle;
  bool get isUploading => status == PublishStatus.uploading;
  bool get isProcessing => status == PublishStatus.processing;
  bool get isSuccess => status == PublishStatus.success;
  bool get isFailed => status == PublishStatus.failed;
  bool get isInProgress => isUploading || isProcessing;
}
