import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/channel_repository.dart';
import '../models/channel.dart';
import '../providers/favorites_provider.dart';
import '../providers/unavailable_channels_provider.dart';
import '../widgets/channel_logo.dart';
import 'player_screen.dart';

const _accent = Color(0xFFB5F36D);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedCountry = 'All';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    final unavailableChannels = ref.watch(unavailableChannelsProvider);
    return Scaffold(
      body: SafeArea(
        child: ref
            .watch(channelsProvider)
            .when(
              data: (channels) => _buildChannelList(
                context,
                channels
                    .where(
                      (channel) => !unavailableChannels.contains(channel.id),
                    )
                    .toList(),
                favorites,
              ),
              loading: () => const _PlaylistLoadingView(),
              error: (error, stackTrace) =>
                  _PlaylistErrorView(error: error, onRetry: _refreshPlaylist),
            ),
      ),
    );
  }

  Widget _buildChannelList(
    BuildContext context,
    List<Channel> allChannels,
    Set<String> favorites,
  ) {
    final categories =
        allChannels.map((channel) => channel.category).toSet().toList()..sort();
    final countries =
        allChannels.map((channel) => channel.country).toSet().toList()..sort();
    const featuredCountries = [
      'Bangladesh',
      'India',
      'Pakistan',
      'Japan',
      'Nepal',
      'USA',
      'China',
    ];
    countries.sort((a, b) {
      final aIndex = featuredCountries.indexOf(a);
      final bIndex = featuredCountries.indexOf(b);
      if (aIndex != -1 || bIndex != -1) {
        if (aIndex == -1) return 1;
        if (bIndex == -1) return -1;
        return aIndex.compareTo(bIndex);
      }
      return a.compareTo(b);
    });
    final languages =
        allChannels
            .map((channel) => channel.language)
            .where((language) => language != 'Unknown')
            .toSet()
            .toList()
          ..sort();
    final categoryFilters = ['All', ...categories, 'Favorites'];
    final countryFilters = ['All', ...countries];
    final languageFilters = ['All', ...languages];
    final query = _searchQuery.trim().toLowerCase();
    final channels = allChannels.where((channel) {
      final matchesCategory = switch (_selectedCategory) {
        'All' => true,
        'Favorites' => favorites.contains(channel.id),
        _ => channel.category == _selectedCategory,
      };
      final matchesCountry =
          _selectedCountry == 'All' || channel.country == _selectedCountry;
      final matchesLanguage =
          _selectedLanguage == 'All' || channel.language == _selectedLanguage;
      final matchesSearch =
          query.isEmpty ||
          channel.name.toLowerCase().contains(query) ||
          channel.category.toLowerCase().contains(query) ||
          channel.country.toLowerCase().contains(query) ||
          channel.language.toLowerCase().contains(query);
      return matchesCategory &&
          matchesCountry &&
          matchesLanguage &&
          matchesSearch;
    }).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: _Header(
              controller: _searchController,
              onSearchChanged: (value) => setState(() => _searchQuery = value),
              onRefresh: () => unawaited(_refreshPlaylist()),
            ),
          ),
        ),
        if (allChannels.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _FeaturedChannel(
                channel: allChannels.first,
                onWatch: () => _openPlayer(context, allChannels.first),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 14),
            child: _SectionHeading(
              title: _selectedCategory == 'Favorites'
                  ? 'Your favorites'
                  : 'Explore channels',
              trailing: '${channels.length} channels',
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _FilterSection(
            label: 'CATEGORY',
            selected: _selectedCategory,
            options: categoryFilters,
            onSelected: (value) => setState(() => _selectedCategory = value),
          ),
        ),
        SliverToBoxAdapter(
          child: _FilterSection(
            label: 'COUNTRY',
            selected: _selectedCountry,
            options: countryFilters,
            onSelected: (value) => setState(() => _selectedCountry = value),
          ),
        ),
        if (languages.isNotEmpty)
          SliverToBoxAdapter(
            child: _FilterSection(
              label: 'LANGUAGE',
              selected: _selectedLanguage,
              options: languageFilters,
              onSelected: (value) => setState(() => _selectedLanguage = value),
            ),
          ),
        if (channels.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyChannels(
              isFavorites: _selectedCategory == 'Favorites',
              hasFilters:
                  _selectedCategory != 'All' ||
                  _selectedCountry != 'All' ||
                  _selectedLanguage != 'All' ||
                  _searchQuery.isNotEmpty,
              onClearFilters: _clearFilters,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final columns = width >= 1000
                    ? 4
                    : width >= 680
                    ? 3
                    : 2;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 158,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _ChannelCard(
                      channel: channels[index],
                      isFavorite: favorites.contains(channels[index].id),
                      onFavorite: () => ref
                          .read(favoritesProvider.notifier)
                          .toggle(channels[index].id),
                      onTap: () => _openPlayer(context, channels[index]),
                    ),
                    childCount: channels.length,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _openPlayer(BuildContext context, Channel channel) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PlayerScreen(
          channel: channel,
          onUnavailable: (channelId) => ref
              .read(unavailableChannelsProvider.notifier)
              .markUnavailable(channelId),
          onAvailable: (channelId) => ref
              .read(unavailableChannelsProvider.notifier)
              .markAvailable(channelId),
        ),
      ),
    );
  }

  Future<void> _refreshPlaylist() async {
    await ref.read(unavailableChannelsProvider.notifier).clear();
    ref.invalidate(channelsProvider);
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = 'All';
      _selectedCountry = 'All';
      _selectedLanguage = 'All';
      _searchQuery = '';
      _searchController.clear();
    });
  }

  String _selectedLanguage = 'All';
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.onSearchChanged,
    required this.onRefresh,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.live_tv_rounded,
                color: Color(0xFF11140E),
                size: 23,
              ),
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HUMU',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.2,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'LIVE TV',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.1,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRefresh,
              tooltip: 'Refresh playlist',
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: controller,
          onChanged: onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search channels or shows',
            hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.white54),
            contentPadding: EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ],
    );
  }
}

class _FeaturedChannel extends StatelessWidget {
  const _FeaturedChannel({required this.channel, required this.onWatch});

  final Channel channel;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 204,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF283A2A), Color(0xFF18221F), Color(0xFF151922)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -32,
            top: -57,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                  width: 30,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(21),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 7, color: Color(0xFF172012)),
                      SizedBox(width: 6),
                      Text(
                        'LIVE NOW',
                        style: TextStyle(
                          color: Color(0xFF172012),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Text(
                  'Your world,\non air.',
                  style: TextStyle(
                    fontSize: 29,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: onWatch,
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: const Color(0xFF11140E),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 19),
                      label: const Text(
                        'Watch live',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${channel.name} · ${channel.country} · ${channel.category}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          trailing,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.label,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String selected;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 7),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = option == selected;
                return ChoiceChip(
                  label: Text(option),
                  selected: isSelected,
                  onSelected: (_) => onSelected(option),
                  showCheckmark: false,
                  selectedColor: _accent,
                  backgroundColor: const Color(0xFF151922),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? const Color(0xFF11140E)
                        : Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistLoadingView extends StatelessWidget {
  const _PlaylistLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading live channels…'),
        ],
      ),
    );
  }
}

class _PlaylistErrorView extends StatelessWidget {
  const _PlaylistErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 36),
            const SizedBox(height: 14),
            const Text(
              'Could not load the playlist',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.channel,
    required this.isFavorite,
    required this.onFavorite,
    required this.onTap,
  });

  final Channel channel;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF131720),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ChannelLogo(channel: channel, size: 42, borderRadius: 14),
                  const Spacer(),
                  IconButton(
                    onPressed: onFavorite,
                    tooltip: isFavorite ? 'Remove favorite' : 'Add favorite',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                    icon: Icon(
                      isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFavorite ? _accent : Colors.white38,
                      size: 19,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${channel.country} · ${channel.category}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.play_circle_outline_rounded,
                    color: Colors.white54,
                    size: 17,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChannels extends StatelessWidget {
  const _EmptyChannels({
    required this.isFavorites,
    required this.hasFilters,
    required this.onClearFilters,
  });

  final bool isFavorites;
  final bool hasFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFavorites
                  ? Icons.favorite_border_rounded
                  : Icons.search_off_rounded,
              color: Colors.white38,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              isFavorites && !hasFilters
                  ? 'No favorites yet'
                  : 'No channels found',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              isFavorites && !hasFilters
                  ? 'Tap the heart on a channel to save it here.'
                  : hasFilters
                  ? 'Try another search or clear the selected filters.'
                  : 'No channels are available right now.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
