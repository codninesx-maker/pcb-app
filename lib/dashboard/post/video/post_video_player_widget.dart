import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class PostVideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const PostVideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<PostVideoPlayerWidget> createState() => _PostVideoPlayerWidgetState();
}

class _PostVideoPlayerWidgetState extends State<PostVideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _controller.setLooping(true);
            _isInitialized = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Handle Facebook-style auto-play / pause based on scroll visibility
  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!_isInitialized) return;

    // If more than 75% of the video is visible on screen, play it automatically
    if (info.visibleFraction >= 0.75) {
      if (!_controller.value.isPlaying) {
        _controller.play();
        setState(() {});
      }
    } else {
      // If scrolled away, pause it
      if (_controller.value.isPlaying) {
        _controller.pause();
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        height: 200,
        color: Colors.black12,
        child: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: _handleVisibilityChanged,
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_controller.value.isPlaying) {
              _controller.pause();
              _showControls = true; // Show play button when manually paused
            } else {
              _controller.play();
              _showControls = false; // Hide controls when playing
            }
          });
        },
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller),

              // Show play/pause button if manually paused or toggled
              if (!_controller.value.isPlaying || _showControls)
                Container(
                  color: Colors.black26,
                  child: Center(
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      radius: 28,
                      child: Icon(
                        _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}