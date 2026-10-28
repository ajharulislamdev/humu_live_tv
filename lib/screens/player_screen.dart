import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/channel.dart';
import '../widgets/channel_logo.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    required this.channel,
    this.onUnavailable,
    this.onAvailable,
    super.key,
  });

  final Channel channel;
  final ValueChanged<String>? onUnavailable;
  final ValueChanged<String>? onAvailable;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  Object? _error;
  bool _isLoading = true;
  int _attempt = 0;
  bool _reportedError = false;
  bool _reportedAvailable = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final attempt = ++_attempt;
    _chewieController?.dispose();
    _chewieController = null;
    final previousController = _videoController;
    _videoController = null;
    await previousController?.dispose();
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _reportedError = false;
      _reportedAvailable = false;
    });

    final videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.channel.streamUrl),
    );
    _videoController = videoController;
    videoController.addListener(
      () => _handleVideoControllerChanged(videoController),
    );
    try {
      await videoController.initialize();
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: videoController,
          autoPlay: true,
          allowFullScreen: true,
          allowMuting: true,
          showControlsOnInitialize: false,
          materialProgressColors: ChewieProgressColors(
            playedColor: Theme.of(context).colorScheme.primary,
            handleColor: Theme.of(context).colorScheme.primary,
            bufferedColor: Colors.white30,
            backgroundColor: Colors.white12,
          ),
        );
        _isLoading = false;
      });
    } catch (error) {
      if (mounted && attempt == _attempt) {
        _reportUnavailable(error);
      }
    }
  }

  String get _errorMessage =>
      _videoController?.value.errorDescription ??
      _error?.toString() ??
      'Playback failed.';

  void _handleVideoControllerChanged(VideoPlayerController controller) {
    if (!mounted || controller != _videoController) {
      return;
    }

    if (controller.value.hasError) {
      _reportUnavailable(
        controller.value.errorDescription ?? 'Playback failed.',
      );
    } else if (controller.value.isPlaying && !_reportedAvailable) {
      _reportedAvailable = true;
      widget.onAvailable?.call(widget.channel.id);
    }
  }

  void _reportUnavailable(Object error) {
    if (_reportedError) return;
    _reportedError = true;
    if (mounted) {
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
    widget.onUnavailable?.call(widget.channel.id);
  }

  @override
  void dispose() {
    _attempt++;
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.channel.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: ColoredBox(
                color: Colors.black,
                child: _error != null
                    ? _PlayerFailure(
                        details: _errorMessage,
                        onRetry: _initializePlayer,
                      )
                    : _isLoading || _chewieController == null
                    ? const _PlayerMessage(
                        icon: Icons.live_tv_rounded,
                        message: 'Connecting to the live stream…',
                        loading: true,
                      )
                    : Chewie(controller: _chewieController!),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              ChannelLogo(
                channel: widget.channel,
                size: 48,
                borderRadius: 15,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.channel.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.channel.description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _StreamStatus(isLoading: _isLoading, hasError: _error != null),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Now streaming',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enjoy the live channel on Humu Live TV. Playback controls are available in the player.',
            style: TextStyle(color: Colors.white60, height: 1.5, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PlayerFailure extends StatelessWidget {
  const _PlayerFailure({required this.details, required this.onRetry});

  final String details;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.signal_wifi_connected_no_internet_4_rounded,
              color: Colors.white54,
              size: 28,
            ),
            const SizedBox(height: 10),
            const Text(
              'This channel could not be played.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              details,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 8),
            const Text(
              'The channel may be offline, blocked in your region, or no longer available.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerMessage extends StatelessWidget {
  const _PlayerMessage({
    required this.icon,
    required this.message,
    this.loading = false,
  });

  final IconData icon;
  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              width: 25,
              height: 25,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            Icon(icon, color: Colors.white54, size: 28),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _StreamStatus extends StatelessWidget {
  const _StreamStatus({required this.isLoading, required this.hasError});

  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final label = isLoading
        ? 'CONNECTING'
        : hasError
        ? 'OFFLINE'
        : 'LIVE';
    final foreground = hasError
        ? const Color(0xFFFFA5AC)
        : const Color(0xFFB5F36D);
    final background = hasError
        ? const Color(0xFF392125)
        : const Color(0xFF283A2A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: foreground, size: 7),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
