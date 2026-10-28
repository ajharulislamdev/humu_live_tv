import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/channel.dart';
import 'm3u_playlist_parser.dart';

class ChannelRepository {
  ChannelRepository({http.Client? client}) : _client = client ?? http.Client();

  static const playlistUrl = 'https://iptv-org.github.io/iptv/index.m3u';
  final http.Client _client;

  Future<List<Channel>> fetchChannels() async {
    final response = await _client
        .get(Uri.parse(playlistUrl))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Playlist request failed with HTTP ${response.statusCode}.',
        Uri.parse(playlistUrl),
      );
    }
    if (response.body.trim().isEmpty) {
      throw const FormatException('The playlist response was empty.');
    }

    final entries = await compute(parseM3uPlaylist, response.body);
    if (entries.isEmpty) {
      throw const FormatException('No valid HTTP streams were found in the playlist.');
    }

    return entries.map(_channelFromEntry).toList(growable: false);
  }

  void dispose() => _client.close();

  Channel _channelFromEntry(Map<String, String> entry) {
    final category = entry['category']!;
    final (icon, color) = _categoryStyle(category);
    return Channel(
      id: entry['id']!,
      name: entry['name']!,
      category: category,
      country: entry['country']!,
      language: entry['language']!,
      description: [
        entry['country'],
        if (entry['language'] != 'Unknown') entry['language'],
        category,
      ].join(' · '),
      icon: icon,
      color: color,
      streamUrl: entry['streamUrl']!,
      logoUrl: entry['logoUrl']!.isEmpty ? null : entry['logoUrl'],
    );
  }

  (IconData, Color) _categoryStyle(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('sport')) {
      return (Icons.sports_basketball_rounded, const Color(0xFFFF9E65));
    }
    if (normalized.contains('news')) {
      return (Icons.newspaper_rounded, const Color(0xFF73B7FF));
    }
    if (normalized.contains('movie') || normalized.contains('film')) {
      return (Icons.movie_creation_rounded, const Color(0xFFFF7EA8));
    }
    if (normalized.contains('music')) {
      return (Icons.graphic_eq_rounded, const Color(0xFF7EDDE0));
    }
    if (normalized.contains('kids') || normalized.contains('children')) {
      return (Icons.toys_rounded, const Color(0xFFFFD166));
    }
    if (normalized.contains('documentary') || normalized.contains('nature')) {
      return (Icons.forest_rounded, const Color(0xFF76D7A5));
    }
    return (Icons.live_tv_rounded, const Color(0xFFBC9AFF));
  }
}

final channelRepositoryProvider = Provider<ChannelRepository>((ref) {
  final repository = ChannelRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final channelsProvider = FutureProvider<List<Channel>>(
  (ref) => ref.watch(channelRepositoryProvider).fetchChannels(),
);
