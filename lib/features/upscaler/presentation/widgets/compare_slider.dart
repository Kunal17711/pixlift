import 'package:flutter/material.dart';

import '../../../../theme/brand_colors.dart';

/// A professional before/after comparator.
///
/// - Single-finger horizontal drag moves the comparison divider.
/// - Pinch / double-tap zooms; two-finger drag pans once zoomed.
/// - One shared transform keeps the comparison pixel-correct while zoomed.
class CompareSlider extends StatefulWidget {
  const CompareSlider({
    super.key,
    required this.before,
    required this.after,
    required this.aspectRatio,
    this.initialFraction = 0.5,
    this.maxScale = 6,
  });

  final Widget before;
  final Widget after;
  final double aspectRatio;
  final double initialFraction;
  final double maxScale;

  @override
  State<CompareSlider> createState() => _CompareSliderState();
}

class _CompareSliderState extends State<CompareSlider> {
  late double _fraction = widget.initialFraction.clamp(0.0, 1.0).toDouble();
  double _scale = 1.0;
  Offset _pan = Offset.zero;

  double _startFraction = 0.5;
  Offset _startFocal = Offset.zero;
  Offset _startPan = Offset.zero;
  double _startScale = 1.0;

  void _onScaleStart(ScaleStartDetails d) {
    _startFraction = _fraction;
    _startFocal = d.focalPoint;
    _startPan = _pan;
    _startScale = _scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final width = context.size?.width ?? widget.aspectRatio * 200;
    if (d.pointerCount == 1) {
      // Single finger: scrub the comparison divider.
      final next = _startFraction + (d.focalPoint.dx - _startFocal.dx) / width;
      setState(() => _fraction = next.clamp(0.0, 1.0));
    } else {
      // Two fingers: zoom + pan.
      final nextScale = (_startScale * d.scale).clamp(1.0, widget.maxScale);
      final focalDelta = d.focalPoint - _startFocal;
      setState(() {
        _scale = nextScale;
        if (_scale > 1.0) {
          _pan = _startPan + focalDelta;
        }
      });
    }
  }

  /// Re-clamps pan so the scaled image always covers the viewport.
  void _clampPan() {
    final size = context.size;
    if (size == null) return;
    final childH = size.width / widget.aspectRatio;
    final scaledW = size.width * _scale;
    final scaledH = childH * _scale;
    _pan = Offset(
      _pan.dx.clamp(size.width - scaledW, 0.0),
      _pan.dy.clamp(size.height - scaledH, 0.0),
    );
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _clampPan();
  }

  void _onDoubleTap() {
    setState(() {
      if (_scale > 1.01) {
        _scale = 1.0;
        _pan = Offset.zero;
      } else {
        _scale = 2.5;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = width / widget.aspectRatio;
          final dividerX = _fraction * width;
          return Semantics(
            label:
                'Before and after image comparison. Drag horizontally to compare.',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              onDoubleTap: _onDoubleTap,
              child: ClipRect(
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _transformed(widget.before),
                      ClipRect(
                        clipper: _RightClipper(_fraction),
                        child: _transformed(widget.after),
                      ),
                      const Align(
                        alignment: Alignment.topLeft,
                        child: _Tag('Before', color: Color(0xCC0B1226)),
                      ),
                      const Align(
                        alignment: Alignment.topRight,
                        child: _Tag('After', color: BrandColors.brandBlue),
                      ),
                      // Divider + handle.
                      Positioned(
                        left: dividerX - 1.5,
                        top: 0,
                        bottom: 0,
                        width: 3,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(color: Colors.black38, blurRadius: 6),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: BrandColors.primaryGradient,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.compare_arrows_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _transformed(Widget child) {
    return Transform.translate(
      offset: _pan,
      child: Transform.scale(
        alignment: Alignment.topLeft,
        scale: _scale,
        child: child,
      ),
    );
  }
}

class _RightClipper extends CustomClipper<Rect> {
  const _RightClipper(this.fraction);
  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * fraction, 0, size.width, size.height);

  @override
  bool shouldReclip(_RightClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
