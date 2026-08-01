import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../generated/app_localizations.dart';

class ProfileImageEditor extends StatefulWidget {
  final String imagePath;

  const ProfileImageEditor({super.key, required this.imagePath});

  @override
  State<ProfileImageEditor> createState() => _ProfileImageEditorState();
}

class _ProfileImageEditorState extends State<ProfileImageEditor> {
  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _transformationController = TransformationController();
  int _rotationAngle = 0; // in degrees (0, 90, 180, 270)
  double _zoomScale = 1.0;
  bool _isSaving = false;

  void _rotateImage() {
    setState(() {
      _rotationAngle = (_rotationAngle + 90) % 360;
      _transformationController.value = Matrix4.identity();
      _zoomScale = 1.0;
    });
  }

  void _reset() {
    setState(() {
      _rotationAngle = 0;
      _transformationController.value = Matrix4.identity();
      _zoomScale = 1.0;
    });
  }

  Future<void> _saveCroppedImage() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    try {
      // Small delay to ensure UI updates are settled
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception("Could not find crop repaint boundary");
      }

      // Capture image with high resolution pixel ratio (3.0 keeps the image crisp and premium)
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception("Failed to convert image to byte data");
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/cropped_profile_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(pngBytes);

      if (mounted) {
        Navigator.pop(context, tempFile.path);
      }
    } catch (e) {
      debugPrint('[ProfileImageEditor] Error cropping image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.imageProcessingError, style: GoogleFonts.cairo()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double cropAreaSize = 280.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          AppLocalizations.of(context)!.editProfileImage,
          style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _reset,
            tooltip: AppLocalizations.of(context)!.resetAction,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // The RepaintBoundary enclosing only the crop area viewport
                    RepaintBoundary(
                      key: _cropKey,
                      child: Container(
                        width: cropAreaSize,
                        height: cropAreaSize,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E1E1E),
                          shape: BoxShape.circle,
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return InteractiveViewer(
                              transformationController: _transformationController,
                              minScale: 0.5,
                              maxScale: 5.0,
                              onInteractionUpdate: (details) {
                                // Track current zoom scale
                                final matrix = _transformationController.value;
                                setState(() {
                                  _zoomScale = matrix.getMaxScaleOnAxis();
                                });
                              },
                              child: Center(
                                child: Transform.rotate(
                                  angle: _rotationAngle * pi / 180,
                                  child: Image.file(
                                    File(widget.imagePath),
                                    fit: BoxFit.contain,
                                    width: constraints.maxWidth,
                                    height: constraints.maxHeight,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Beautiful overlay ring to visually show the circular border clearly on black background
                    IgnorePointer(
                      child: Container(
                        width: cropAreaSize + 2,
                        height: cropAreaSize + 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2.0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Zoom Indicator & Rotation Controls panel
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Zoom Level text indicator
                  Text(
                    AppLocalizations.of(context)!.zoomLevel(_zoomScale.toStringAsFixed(1)),
                    style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Action Button Controls (Rotate & Save)
                  Row(
                    children: [
                      // Rotate Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _rotateImage,
                          icon: const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 20),
                          label: Text(
                            AppLocalizations.of(context)!.rotate90,
                            style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Save Button with Loader
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveCroppedImage,
                          icon: _isSaving 
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.check, color: Colors.white, size: 20),
                          label: Text(
                            _isSaving ? AppLocalizations.of(context)!.savingImage : AppLocalizations.of(context)!.saveCircularImage,
                            style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mediumBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
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
      ),
    );
  }
}
