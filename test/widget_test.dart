import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:humu_live_tv/data/channel_repository.dart';
import 'package:humu_live_tv/main.dart';
import 'package:humu_live_tv/models/channel.dart';
import 'package:humu_live_tv/screens/player_screen.dart';

const _testChannels = <Channel>[
  Channel(
    id: 'humu-news',
    name: 'Humu News',
    category: 'News',
    country: 'Bangladesh',
    language: 'Unknown',
    description: 'BD · News',
    icon: Icons.newspaper_rounded,
    color: Color(0xFF73B7FF),
    streamUrl: 'https://example.com/humu.m3u8',
  ),
  Channel(
    id: 'world-now',
    name: 'World Now',
    category: 'News',
    country: 'USA',
    language: 'Unknown',
    description: 'US · News',
    icon: Icons.public_rounded,
    color: Color(0xFFBC9AFF),
    streamUrl: 'https://example.com/world.m3u8',
  ),
  Channel(
    id: 'stadium-live',
    name: 'Stadium Live',
    category: 'Sports',
    country: 'USA',
    language: 'Unknown',
    description: 'US · Sports',
    icon: Icons.sports_basketball_rounded,
    color: Color(0xFFFF9E65),
    streamUrl: 'https://example.com/stadium.m3u8',
  ),
  Channel(
    id: 'b4u-bhojpuri',
    name: 'B4U Bhojpuri',
    category: 'Movies',
    country: 'India',
    language: 'Bhojpuri',
    description: 'India · Bhojpuri · Movies',
    icon: Icons.movie_creation_rounded,
    color: Color(0xFFFF7EA8),
    streamUrl: 'https://example.com/bhojpuri.m3u8',
  ),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows channels and filters them by search', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('HUMU'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Stadium');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Stadium Live'), findsOneWidget);
    expect(find.text('World Now'), findsNothing);
  });

  testWidgets('filters channels by country', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bangladesh').last);
    await tester.pumpAndSettle();

    expect(find.text('Humu News'), findsOneWidget);
    expect(find.text('World Now'), findsNothing);
  });

  testWidgets('offers to clear filters when no channels match', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Bangladesh'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bangladesh'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Sports'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sports'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('No channels found'), findsOneWidget);
    await tester.ensureVisible(find.text('Clear filters'));
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Humu News'), findsOneWidget);
    expect(find.text('No channels found'), findsNothing);
  });

  testWidgets('filters channels by Bhojpuri language', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bhojpuri'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('B4U Bhojpuri'), findsOneWidget);
    expect(find.text('World Now'), findsNothing);
  });

  testWidgets('hides channels previously marked unavailable', (tester) async {
    SharedPreferences.setMockInitialValues({
      'unavailable_channels': ['world-now'],
    });
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Humu News'), findsOneWidget);
    expect(find.text('World Now'), findsNothing);
  });

  testWidgets('saves a channel to favorites', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add favorite').first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 700));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ChoiceChip).first, const Offset(-700, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Humu News'), findsOneWidget);
    expect(find.text('World Now'), findsNothing);
  });

  testWidgets('shows a retry option when stream initialization fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PlayerScreen(channel: _testChannels.first)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('This channel could not be played.'), findsOneWidget);
    expect(find.text('OFFLINE'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

Widget _testApp() {
  return ProviderScope(
    overrides: [channelsProvider.overrideWith((ref) async => _testChannels)],
    child: const HumuLiveTvApp(),
  );
}
