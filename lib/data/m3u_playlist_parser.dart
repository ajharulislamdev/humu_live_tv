List<Map<String, String>> parseM3uPlaylist(String playlist) {
  final channels = <Map<String, String>>[];
  Map<String, String>? pendingChannel;

  for (final rawLine in playlist.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#EXTM3U')) continue;

    if (line.startsWith('#EXTINF:')) {
      final separator = _findDisplayNameSeparator(line);
      if (separator == -1) {
        pendingChannel = null;
        continue;
      }

      final metadata = line.substring(0, separator);
      final attributes = _parseAttributes(metadata);
      final displayName = line.substring(separator + 1).trim();
      final name = _firstNonEmpty([
        attributes['tvg-name'],
        displayName,
      ]);
      if (name == null) {
        pendingChannel = null;
        continue;
      }

      final tvgId = attributes['tvg-id'] ?? '';
      final country = _firstCountry(attributes['tvg-country'], tvgId);
      final category = _firstCategory(attributes['group-title']);
      final language = _channelLanguage(name, attributes['tvg-language']);
      pendingChannel = {
        'name': name,
        'tvg-id': tvgId,
        'logo-url': _validImageUrl(attributes['tvg-logo']) ?? '',
        'country': country,
        'category': category,
        'language': language,
      };
      continue;
    }

    if (line.startsWith('#')) continue;
    final channel = pendingChannel;
    pendingChannel = null;
    if (channel == null) continue;

    final uri = Uri.tryParse(line);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      continue;
    }

    final streamUrl = uri.toString();
    final tvgId = channel['tvg-id']!;
    channels.add({
      'id': tvgId.isEmpty ? streamUrl : '$tvgId::$streamUrl',
      'name': channel['name']!,
      'logoUrl': channel['logo-url']!,
      'country': channel['country']!,
      'category': channel['category']!,
      'language': channel['language']!,
      'streamUrl': streamUrl,
    });
  }

  return channels;
}

int _findDisplayNameSeparator(String line) {
  var quote = '';
  for (var index = 0; index < line.length; index++) {
    final character = line[index];
    if (quote.isNotEmpty) {
      if (character == quote) quote = '';
    } else if (character == '"' || character == "'") {
      quote = character;
    } else if (character == ',') {
      return index;
    }
  }
  return -1;
}

Map<String, String> _parseAttributes(String metadata) {
  final attributes = <String, String>{};
  final pattern = RegExp(
    r'''([\w-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s,]+))''',
  );
  for (final match in pattern.allMatches(metadata)) {
    attributes[match.group(1)!.toLowerCase()] =
        match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
  }
  return attributes;
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

String _firstCountry(String? value, String tvgId) {
  final taggedCountry = _firstNonEmpty(
    value?.split(RegExp(r'[,;]')) ?? const [],
  );
  final country = taggedCountry ?? _countryCodeFromTvgId(tvgId);
  if (country == null) return 'Unknown';

  const countryNames = {
    'bd': 'Bangladesh',
    'cn': 'China',
    'in': 'India',
    'jp': 'Japan',
    'np': 'Nepal',
    'pk': 'Pakistan',
    'us': 'USA',
  };
  return countryNames[country.toLowerCase()] ?? country;
}

String? _countryCodeFromTvgId(String tvgId) {
  final match = RegExp(r'\.([a-z]{2})(?:@|$)', caseSensitive: false)
      .firstMatch(tvgId);
  return match?.group(1);
}

String? _validImageUrl(String? value) {
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return uri.toString();
}

String _channelLanguage(String name, String? taggedLanguage) {
  final language = taggedLanguage?.toLowerCase() ?? '';
  if (name.toLowerCase().contains('bhojpuri') ||
      language.contains('bhojpuri') ||
      language.split(RegExp(r'[,;]')).contains('bho')) {
    return 'Bhojpuri';
  }
  return _firstNonEmpty(taggedLanguage?.split(RegExp(r'[,;]')) ?? const []) ??
      'Unknown';
}

String _firstCategory(String? value) {
  final category = _firstNonEmpty(value?.split(RegExp(r'[;,]')) ?? const []);
  return category ?? 'Other';
}
