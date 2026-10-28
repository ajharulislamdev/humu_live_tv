import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, Set<String>>(FavoritesNotifier.new);

class FavoritesNotifier extends Notifier<Set<String>> {
  late Future<void> _restoreFuture;

  @override
  Set<String> build() {
    _restoreFuture = _restoreFavorites();
    return const {};
  }

  Future<void> toggle(String channelId) async {
    await _restoreFuture;
    final updated = Set<String>.of(state);
    if (!updated.add(channelId)) {
      updated.remove(channelId);
    }

    state = Set.unmodifiable(updated);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('favorite_channels', updated.toList());
  }

  Future<void> _restoreFavorites() async {
    final preferences = await SharedPreferences.getInstance();
    if (ref.mounted) {
      state = Set.unmodifiable(
        preferences.getStringList('favorite_channels')?.toSet() ?? <String>{},
      );
    }
  }
}
