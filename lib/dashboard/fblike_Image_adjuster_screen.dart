import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class FacebookImageAdjusterScreen extends StatefulWidget {
  final File imageFile;
  final bool isCover;

  const FacebookImageAdjusterScreen({
    super.key,
    required this.imageFile,
    required this.isCover,
  });

  @override
  State<FacebookImageAdjusterScreen> createState() =>
      _FacebookImageAdjusterScreenState();
}

class _FacebookImageAdjusterScreenState
    extends State<FacebookImageAdjusterScreen> {
  final TransformationController _transformationController =
  TransformationController();
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isSaving = false;

  Future<void> _cropAndSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // 1. Find the render boundary of the framed container
      RenderRepaintBoundary boundary = _boundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      // 2. Convert the visible frame to an cloud
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // 3. Write bytes to a temporary file
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        // 4. Return the newly cropped file back to the profile screen
        Navigator.pop(context, file);
      }
    } catch (e) {
      debugPrint("Error cropping cloud: $e");
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save cloud: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double targetAspectRatio = widget.isCover ? (16 / 9) : 1.0;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          widget.isCover ? "Adjust Cover Photo" : "Adjust Profile Picture",
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _cropAndSave,
            child: _isSaving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.blueAccent,
                strokeWidth: 2,
              ),
            )
                : const Text(
              "SAVE",
              style: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: targetAspectRatio,
          child: RepaintBoundary(
            key: _boundaryKey,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
              ),
              child: ClipRect(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  boundaryMargin: const EdgeInsets.all(300),
                  minScale: 0.5,
                  maxScale: 5.0,
                  constrained: false,
                  child: Image.file(
                    widget.imageFile,
                    width: screenWidth,
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}