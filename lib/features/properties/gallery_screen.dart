import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'models.dart';

/// Full-screen photo viewer: swipe between photos, pinch or double-tap to zoom.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, required this.media, this.initialIndex = 0});

  final List<MediaItem> media;
  final int initialIndex;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _zoomed = false; // while zoomed in, a drag pans the photo instead of changing page

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('${_index + 1} / ${widget.media.length}', style: const TextStyle(fontSize: 16)),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pages,
        physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
        itemCount: widget.media.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => _ZoomablePhoto(
          url: widget.media[i].url,
          onZoomChanged: (zoomed) {
            if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
          },
        ),
      ),
    );
  }
}

class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({required this.url, required this.onZoomChanged});

  final String url;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> with SingleTickerProviderStateMixin {
  final _controller = TransformationController();
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  Animation<Matrix4>? _tween;
  Offset _tapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      final t = _tween;
      if (t != null) _controller.value = t.value;
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool get _isZoomedIn => _controller.value.getMaxScaleOnAxis() > 1.05;

  void _doubleTap() {
    final end = _isZoomedIn
        ? Matrix4.identity()
        : (Matrix4.identity()
          ..translateByDouble(-_tapAt.dx * 1.5, -_tapAt.dy * 1.5, 0, 1)
          ..scaleByDouble(2.5, 2.5, 1, 1));
    _tween = Matrix4Tween(begin: _controller.value, end: end).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward(from: 0).whenComplete(() => widget.onZoomChanged(_isZoomedIn));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _tapAt = d.localPosition,
      onDoubleTap: _doubleTap,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 5,
        onInteractionEnd: (_) => widget.onZoomChanged(_isZoomedIn),
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.url,
            fit: BoxFit.contain,
            placeholder: (_, _) => const Center(child: CircularProgressIndicator(color: Colors.white)),
            errorWidget: (_, _, _) =>
                const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 56)),
          ),
        ),
      ),
    );
  }
}
