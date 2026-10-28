import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:humu_live_tv/providers/unavailable_channels_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists unavailable channels and restores them', () async {
    final firstContainer = ProviderContainer();
    addTearDown(firstContainer.dispose);

    await firstContainer
        .read(unavailableChannelsProvider.notifier)
        .markUnavailable('offline-channel');
    expect(
      firstContainer.read(unavailableChannelsProvider),
      contains('offline-channel'),
    );

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList('unavailable_channels'),
      contains('offline-channel'),
    );

    final secondContainer = ProviderContainer();
    addTearDown(secondContainer.dispose);
    await secondContainer
        .read(unavailableChannelsProvider.notifier)
        .markUnavailable('another-offline-channel');

    expect(
      secondContainer.read(unavailableChannelsProvider),
      containsAll(['offline-channel', 'another-offline-channel']),
    );
  });

  test('clears unavailable channels to allow rechecking', () async {
    SharedPreferences.setMockInitialValues({
      'unavailable_channels': ['offline-channel'],
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(unavailableChannelsProvider.notifier).clear();

    expect(container.read(unavailableChannelsProvider), isEmpty);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('unavailable_channels'), isNull);
  });
}
