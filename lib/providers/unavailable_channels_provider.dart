import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final unavailableChannelsProvider = NotifierProvider<
  UnavailableChannelsNotifier,
  Set<String>
>(UnavailableChannelsNotifier.new);

class UnavailableChannelsNotifier extends Notifier<Set<String>> {
  late Future<void> _restoreFuture;

  @override
  Set<String> build() {
    _restoreFuture = _restore();
    return const {};
  }

  Future<void> markUnavailable(String channelId) async {
    await _restoreFuture;
    final updated = Set<String>.of(state)..add(channelId);
    state = Set.unmodifiable(updated);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('unavailable_channels', updated.toList());
  }

  Future<void> markAvailable(String channelId) async {
    await _restoreFuture;
    if (!state.contains(channelId)) return;
    final updated = Set<String>.of(state)..remove(channelId);
    state = Set.unmodifiable(updated);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('unavailable_channels', updated.toList());
  }

  Future<void> clear() async {
    await _restoreFuture;
    state = const {};
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('unavailable_channels');
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    if (ref.mounted) {
      state = Set.unmodifiable(
        preferences.getStringList('unavailable_channels')?.toSet() ??
            <String>{},
      );
    }
  }
}
