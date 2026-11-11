import 'package:flutter_test/flutter_test.dart';
import 'package:zitok/models/drama_models.dart';

void main() {
  test('Episode sort by episodeNo stable for loader expectation', () {
    final eps = [
      const Episode(id: 2, dramaId: 1, episodeNo: 2),
      const Episode(id: 1, dramaId: 1, episodeNo: 1),
      const Episode(id: 3, dramaId: 1, episodeNo: 3),
    ]..sort((a, b) => a.episodeNo.compareTo(b.episodeNo));
    expect(eps.map((e) => e.id).toList(), [1, 2, 3]);
  });
}
