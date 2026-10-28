import 'package:flutter_test/flutter_test.dart';

import 'package:humu_live_tv/data/m3u_playlist_parser.dart';

void main() {
  test('parses channel name, stream URL, country, and category', () {
    const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="bd.news" tvg-name="News, HD" tvg-logo="https://logos.example.com/bd.png" tvg-country="BD" group-title="News;National",Bangladesh News
#EXTVLCOPT:http-user-agent=Test Player
https://streams.example.com/bd-news.m3u8
#EXTINF:-1 tvg-country="US" group-title="Sports",World Sports
https://streams.example.com/world-sports.m3u8
''';

    final channels = parseM3uPlaylist(playlist);

    expect(channels, hasLength(2));
    expect(channels.first['name'], 'News, HD');
    expect(channels.first['logoUrl'], 'https://logos.example.com/bd.png');
    expect(channels.first['country'], 'Bangladesh');
    expect(channels.first['category'], 'News');
    expect(
      channels.first['streamUrl'],
      'https://streams.example.com/bd-news.m3u8',
    );
    expect(channels.last['name'], 'World Sports');
    expect(channels.last['country'], 'USA');
    expect(channels.last['category'], 'Sports');
  });

  test(
    'infers requested countries and Bhojpuri from tvg-id and channel name',
    () {
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="B4UBhojpuri.in@SD" group-title="Movies",B4U Bhojpuri (1080p)
https://streams.example.com/bhojpuri.m3u8
#EXTINF:-1 tvg-id="NHKWorldPremium.jp@HD" group-title="General",NHK World Premium
https://streams.example.com/japan.m3u8
''';

      final channels = parseM3uPlaylist(playlist);

      expect(channels.first['country'], 'India');
      expect(channels.first['language'], 'Bhojpuri');
      expect(channels.last['country'], 'Japan');
      expect(channels.last['language'], 'Unknown');
    },
  );

  test('ignores malformed entries and non-HTTP stream URLs', () {
    const playlist = '''
#EXTM3U
#EXTINF:-1,Unsupported
file:///private/stream.m3u8
#EXTINF:-1 tvg-name="Valid",Valid Channel
https://streams.example.com/valid.m3u8
''';

    final channels = parseM3uPlaylist(playlist);

    expect(channels, hasLength(1));
    expect(channels.single['name'], 'Valid');
    expect(channels.single['country'], 'Unknown');
    expect(channels.single['category'], 'Other');
  });

  test('ignores non-HTTP logo URLs', () {
    const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-logo="file:///private/logo.png",Channel
https://streams.example.com/live.m3u8
''';

    final channels = parseM3uPlaylist(playlist);

    expect(channels.single['logoUrl'], '');
  });
}
