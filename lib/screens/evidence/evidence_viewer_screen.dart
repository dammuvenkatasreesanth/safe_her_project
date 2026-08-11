import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/recording.dart';
import '../../services/evidence_service.dart';

/// Shows a single decrypted evidence file. Only ever reached after a
/// BiometricService.authenticate() success (see EvidenceScreen) — the
/// decrypted [file] is a transient temp copy that this screen deletes as
/// soon as it's closed, so the plaintext never outlives the view.
class EvidenceViewerScreen extends StatefulWidget {
  const EvidenceViewerScreen({super.key, required this.recording, required this.file});

  final Recording recording;
  final File file;

  @override
  State<EvidenceViewerScreen> createState() => _EvidenceViewerScreenState();
}

class _EvidenceViewerScreenState extends State<EvidenceViewerScreen> {
  VideoPlayerController? _controller;
  bool _playbackError = false;

  @override
  void initState() {
    super.initState();
    if (widget.recording.type != RecordingType.photo) {
      final controller = VideoPlayerController.file(widget.file);
      _controller = controller;
      controller
          .initialize()
          .then((_) {
            if (!mounted) return;
            setState(() {});
            controller.play();
          })
          .catchError((_) {
            if (mounted) setState(() => _playbackError = true);
          });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    EvidenceService.cleanupDecrypted(widget.file);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.recording.title, overflow: TextOverflow.ellipsis),
      ),
      body: Center(child: _content()),
    );
  }

  Widget _content() {
    if (widget.recording.type == RecordingType.photo) {
      return InteractiveViewer(child: Image.file(widget.file));
    }

    if (_playbackError) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          "Couldn't play this file.",
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.recording.type == RecordingType.video)
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          )
        else
          const Icon(Icons.mic_rounded, color: Colors.white, size: 80),
        const SizedBox(height: 16),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) => IconButton(
            icon: Icon(
              value.isPlaying ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
              color: Colors.white,
              size: 56,
            ),
            onPressed: () => value.isPlaying ? controller.pause() : controller.play(),
          ),
        ),
      ],
    );
  }
}
