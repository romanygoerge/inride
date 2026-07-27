import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class CameraCaptureDialog extends StatefulWidget {
  final String title;
  final bool isPickup; // true for pickup, false for delivery
  final bool isReceipt; // true for transaction receipt, false for packages

  const CameraCaptureDialog({
    super.key,
    required this.title,
    required this.isPickup,
    this.isReceipt = false,
  });

  @override
  State<CameraCaptureDialog> createState() => _CameraCaptureDialogState();
}

class _CameraCaptureDialogState extends State<CameraCaptureDialog> {
  bool _isCaptured = false;
  bool _flashOn = false;
  bool _showGrid = true;
  bool _triggerFlashOverlay = false;

  String get _mockImageUrl {
    if (widget.isReceipt) {
      return 'https://images.unsplash.com/photo-1554415707-6e8cfc93fe23?auto=format&fit=crop&q=80&w=600';
    }
    return widget.isPickup
        ? 'https://images.unsplash.com/photo-1566576912321-d58edd7a2858?auto=format&fit=crop&q=80&w=600'
        : 'https://images.unsplash.com/photo-1595079676339-1534801ad6cf?auto=format&fit=crop&q=80&w=600';
  }

  void _capturePhoto() {
    setState(() {
      _triggerFlashOverlay = true;
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _triggerFlashOverlay = false;
          _isCaptured = true;
        });
      }
    });
  }

  void _retakePhoto() {
    setState(() {
      _isCaptured = false;
    });
  }

  void _confirmPhoto() {
    Navigator.of(context).pop(_mockImageUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.7,
          color: Colors.black,
          child: Stack(
            children: [
              // 1. Camera Viewfinder or Captured Preview
              Positioned.fill(
                child: _isCaptured
                    ? Image.network(
                        _mockImageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[900],
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.isReceipt ? Icons.receipt_long : Icons.image_not_supported,
                                  color: Colors.white70,
                                  size: 64,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  widget.isReceipt ? 'تم التقاط الإيصال بنجاح' : 'تم التقاط الصورة بنجاح',
                                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'انقر على "تأكيد الصورة" للمتابعة',
                                  style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[900],
                        child: Stack(
                          children: [
                            // Viewfinder grid lines
                            if (_showGrid) ...[
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: CameraGridPainter(),
                                ),
                              ),
                            ],
                            // Viewfinder Corner Brackets for Scanner effect
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.all(40.0),
                                child: CustomPaint(
                                  painter: CameraViewfinderPainter(),
                                ),
                              ),
                            ),
                            // Simulated Camera Feed Text
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.center_focus_weak,
                                    color: Colors.white60,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    widget.isReceipt
                                        ? 'ضع الإيصال في منتصف الكاميرا'
                                        : (widget.isPickup
                                            ? 'ضع الطرد في المنتصف للاستلام'
                                            : 'صوّر الطرد عند مكان التسليم'),
                                    style: GoogleFonts.cairo(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              // 2. Flash Overlay Flash Animation
              if (_triggerFlashOverlay)
                Positioned.fill(
                  child: Container(color: Colors.white),
                ),

              // 3. Top Action Controls (Back, Grid, Flash)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black54, Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        widget.title,
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Row(
                        children: [
                          if (!_isCaptured) ...[
                            IconButton(
                              icon: Icon(
                                _showGrid ? Icons.grid_on : Icons.grid_off,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showGrid = !_showGrid;
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                _flashOn ? Icons.flash_on : Icons.flash_off,
                                color: _flashOn ? Colors.amber : Colors.white,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _flashOn = !_flashOn;
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Bottom Controls (Shutter Button / Action confirmation)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: _isCaptured
                      ? Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white60),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.replay),
                                label: Text(
                                  'إعادة تصوير',
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                                ),
                                onPressed: _retakePhoto,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    colors: AppColors.blueGradient,
                                  ),
                                ),
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: const Icon(Icons.check),
                                  label: Text(
                                    'تأكيد الصورة',
                                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: _confirmPhoto,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: GestureDetector(
                            onTap: _capturePhoto,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
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

class CameraGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0;

    // Draw vertical lines
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);

    // Draw horizontal lines
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CameraViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white60
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    const length = 20.0;

    // Top Left Corner
    canvas.drawPath(
      Path()
        ..moveTo(0, length)
        ..lineTo(0, 0)
        ..lineTo(length, 0),
      paint,
    );

    // Top Right Corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - length, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, length),
      paint,
    );

    // Bottom Left Corner
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - length)
        ..lineTo(0, size.height)
        ..lineTo(length, size.height),
      paint,
    );

    // Bottom Right Corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - length, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - length),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
