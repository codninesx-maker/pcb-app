import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class FeedVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const FeedVideoPlayer({super.key, required this.videoUrl});

  @override
  State<FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<FeedVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    if (widget.videoUrl.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isInitialized = true;
              _controller.setVolume(1.0);
              _controller.setLooping(true);

              // Optional: Listen to buffering state to show indicator if connection lags
              _controller.addListener(() {
                if (mounted) setState(() {});
              });
            });
          }
        });
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showControls = true;
      } else {
        _controller.play();
        _showControls = false;
      }
    });
  }

  // Opens Facebook-style immersive full-screen view
  void _openFullScreen(BuildContext context) {
    // Pause feed view playback while opening full screen
    final wasPlaying = _controller.value.isPlaying;
    _controller.pause();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenVideoScreen(
          controller: _controller,
          wasPlaying: wasPlaying,
        ),
      ),
    ).then((_) {
      // Resume or update state when coming back from full screen
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videoUrl.isEmpty) {
      return const Center(
        child: Text("Video unavailable", style: TextStyle(color: Colors.white)),
      );
    }

    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          ),
          if (_showControls || !_controller.value.isPlaying)
            Container(
              color: Colors.black26,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        color: Colors.white.withOpacity(0.9),
                        size: 64,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                  ],
                ),
              ),
            ),

          // Fullscreen expand button top-right/bottom-right like Facebook
          Positioned(
            bottom: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.fullscreen, color: Colors.white, size: 28),
              onPressed: () => _openFullScreen(context),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.blueAccent,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dedicated Full-Screen Player Route (Facebook Reel/Video immersive style)
class _FullScreenVideoScreen extends StatefulWidget {
  final VideoPlayerController controller;
  final bool wasPlaying;

  const _FullScreenVideoScreen({
    required this.controller,
    required this.wasPlaying,
  });

  @override
  State<_FullScreenVideoScreen> createState() => _FullScreenVideoScreenState();
}

class _FullScreenVideoScreenState extends State<_FullScreenVideoScreen> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    // Set status bar and orientation configurations for immersive full screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (widget.wasPlaying) {
      widget.controller.play();
    }
  }

  @override
  void dispose() {
    // Restore system UI overlays when exiting full screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (widget.controller.value.isPlaying) {
        widget.controller.pause();
        _showControls = true;
      } else {
        widget.controller.play();
        _showControls = false;
      }
    });
  }

  @override
  Widget build(context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),
            if (_showControls)
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Bar with back button
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    // Center Play/Pause button
                    IconButton(
                      icon: Icon(
                        widget.controller.value.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        color: Colors.white.withOpacity(0.9),
                        size: 72,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                    // Bottom Progress bar
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: VideoProgressIndicator(
                        widget.controller,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Colors.blueAccent,
                          bufferedColor: Colors.white30,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}