import 'dart:typed_data';

import 'package:flutter/material.dart';

/// A photographed nota at full frame width, nothing cropped.
///
/// A tall slip pans up and down at 1x; double-tap or pinch zooms in, which is what unlocks
/// panning left and right. Double-tap again (or the fit button) returns to 1x.
class NotaPhotoViewer extends StatefulWidget {
  const NotaPhotoViewer({
    super.key,
    required this.bytes,
    required this.controller,
    required this.hint,
    required this.fitLabel,
    required this.fullscreenLabel,
    this.onFullscreen,
  });

  final Uint8List bytes;
  final TransformationController controller;
  final String hint;
  final String fitLabel;
  final String fullscreenLabel;
  final VoidCallback? onFullscreen;

  /// How far a double-tap zooms in.
  static const double doubleTapScale = 2.5;

  @override
  State<NotaPhotoViewer> createState() => _NotaPhotoViewerState();
}

class _NotaPhotoViewerState extends State<NotaPhotoViewer> {
  Offset? _doubleTapAt;

  void _toggleZoom() {
    final at = _doubleTapAt;
    if (at == null) return;
    final c = widget.controller;
    if (c.value.getMaxScaleOnAxis() > 1.01) {
      c.value = Matrix4.identity();
      return;
    }
    const s = NotaPhotoViewer.doubleTapScale;
    final p = c.toScene(at); // keep the tapped point under the finger
    c.value = Matrix4.identity()
      ..translateByDouble(at.dx - s * p.dx, at.dy - s * p.dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: cs.surfaceContainerHighest,
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, box) => GestureDetector(
                key: const ValueKey('nota-photo-gestures'),
                behavior: HitTestBehavior.opaque,
                onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
                onDoubleTap: _toggleZoom,
                child: InteractiveViewer(
                  transformationController: widget.controller,
                  // Unconstrained so the image keeps its own height: a portrait nota is taller
                  // than the frame, and that overflow is what allows vertical panning at 1x.
                  constrained: false,
                  minScale: 1,
                  maxScale: 6,
                  boundaryMargin: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: box.maxWidth,
                    child: Image.memory(
                      widget.bytes,
                      width: box.maxWidth,
                      fit: BoxFit.fitWidth,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(left: 8, bottom: 8, child: _chip(widget.hint)),
            Positioned(
              right: 8,
              bottom: 8,
              child: Row(
                children: [
                  _button(Icons.fit_screen_outlined, widget.fitLabel,
                      () => widget.controller.value = Matrix4.identity()),
                  if (widget.onFullscreen != null) ...[
                    const SizedBox(width: 6),
                    _button(Icons.fullscreen, widget.fullscreenLabel, widget.onFullscreen!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pan_tool_alt_outlined, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      );

  Widget _button(IconData icon, String tooltip, VoidCallback onTap) => Material(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Tooltip(
            message: tooltip,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      );
}
