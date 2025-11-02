import '../models/video.dart';
import '../services/mock/mock_video_service.dart';

class VideoRepository {
  final MockVideoService mock;
  const VideoRepository({required this.mock});

  Future<PagedResult<Video>> fetchDiscover(VideoQuery query) => mock.fetch(query);
  Future<PagedResult<Video>> fetchFeatured(VideoQuery query) => mock.fetch(query);
  Future<PagedResult<Video>> fetchFollow(VideoQuery query) => mock.fetchFollow(query);
}