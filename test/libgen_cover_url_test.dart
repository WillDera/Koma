import 'package:flutter_test/flutter_test.dart';

import 'package:koma/core/services/source_service.dart';

void main() {
  test('rewrites fictionruscovers onto libgen.li and drops _small', () {
    expect(
      resolveLibgenCoverUrl(
        'https://libgen.gs/index.php?req=x',
        '/fictionruscovers/221000/166ff7c1914a28a7057f72f9e3083452_small.jpg',
      ),
      'https://libgen.li/fictionruscovers/221000/166ff7c1914a28a7057f72f9e3083452.jpg',
    );
  });

  test('rewrites fictioncovers onto libgen.li', () {
    expect(
      resolveLibgenCoverUrl(
        'https://libgen.li/index.php?req=x',
        '/fictioncovers/4839000/afe92fc8df235eca6e0d96b6612403a6_small.jpg',
      ),
      'https://libgen.li/fictioncovers/4839000/afe92fc8df235eca6e0d96b6612403a6.jpg',
    );
  });

  test('default sources list is empty (user adds sources)', () {
    expect(SourceService.defaultSources(), isEmpty);
  });
}
