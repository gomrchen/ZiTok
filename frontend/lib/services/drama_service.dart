import 'package:dio/dio.dart';

class DramaService {
  final Dio dio;
  DramaService(this.dio);

  Future<Response> feed({int page = 1, int size = 10}) =>
      dio.get('/drama/feed', queryParameters: {'page': page, 'size': size});

  Future<Response> list({int page = 1, int size = 20, String? category}) =>
      dio.get('/drama/list', queryParameters: {
        'page': page,
        'size': size,
        if (category != null && category.isNotEmpty) 'category': category,
      });

  Future<Response> search({required String q, int page = 1, int size = 20}) =>
      dio.get('/drama/search', queryParameters: {'q': q, 'page': page, 'size': size});

  Future<Response> detail(int id) => dio.get('/drama/$id');

  Future<Response> episodes(int dramaId) => dio.get('/drama/$dramaId/episodes');

  Future<Response> playInfo(int episodeId) => dio.get('/drama/episode/$episodeId/play');

  Future<Response> reportProgress({
    required int dramaId,
    required int episodeId,
    required int episodeNo,
    int positionSec = 0,
  }) =>
      dio.post('/drama/progress', data: {
        'drama_id': dramaId,
        'episode_id': episodeId,
        'episode_no': episodeNo,
        'position_sec': positionSec,
      });

  Future<Response> continueWatching() => dio.get('/drama/continue');

  Future<Response> favorites() => dio.get('/drama/favorites');

  Future<Response> favorite(int dramaId) => dio.post('/drama/$dramaId/favorite');

  Future<Response> unfavorite(int dramaId) => dio.delete('/drama/$dramaId/favorite');
}

class CommerceService {
  final Dio dio;
  CommerceService(this.dio);

  Future<Response> wallet() => dio.get('/commerce/wallet');

  Future<Response> ledger() => dio.get('/commerce/ledger');

  Future<Response> unlockEpisode(int episodeId) =>
      dio.post('/commerce/unlock/episode', data: {'episode_id': episodeId});

  Future<Response> unlockDrama(int dramaId) =>
      dio.post('/commerce/unlock/drama', data: {'drama_id': dramaId});

  Future<Response> adUnlock(int episodeId) =>
      dio.post('/commerce/ad/unlock', data: {'episode_id': episodeId});

  Future<Response> adReward() => dio.post('/commerce/ad/reward');

  Future<Response> mockTopup({int amount = 100}) =>
      dio.post('/commerce/topup/mock', data: {'amount': amount});
}
