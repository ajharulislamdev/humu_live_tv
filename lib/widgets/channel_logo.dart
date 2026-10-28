import 'package:flutter/material.dart';

import '../models/channel.dart';

class ChannelLogo extends StatelessWidget {
  const ChannelLogo({
    required this.channel,
    required this.size,
    required this.borderRadius,
    super.key,
  });

  final Channel channel;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: channel.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: channel.logoUrl == null
          ? _fallbackIcon()
          : Image.network(
              channel.logoUrl!,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _fallbackIcon(),
            ),
    );
  }

  Widget _fallbackIcon() {
    return Icon(channel.icon, color: channel.color, size: size * 0.52);
  }
}
