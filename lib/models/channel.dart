import 'package:flutter/material.dart';

class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.category,
    required this.country,
    required this.language,
    required this.description,
    required this.icon,
    required this.color,
    required this.streamUrl,
    this.logoUrl,
  });

  final String id;
  final String name;
  final String category;
  final String country;
  final String language;
  final String description;
  final IconData icon;
  final Color color;
  final String streamUrl;
  final String? logoUrl;
}
