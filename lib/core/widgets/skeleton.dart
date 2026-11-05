import 'package:flutter/material.dart';

/// A pulsing grey block shown while content loads, so the screen keeps the shape of what
/// is coming instead of showing a lone spinner.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 16, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(scheme.surfaceContainerHigh, scheme.surfaceContainerHighest, _controller.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Stand-in for a listing card while the list loads.
class PropertyCardSkeleton extends StatelessWidget {
  const PropertyCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AspectRatio(aspectRatio: 16 / 10, child: Skeleton(height: double.infinity, radius: 0)),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Skeleton(width: 220, height: 18),
            SizedBox(height: 10),
            Skeleton(width: 140, height: 14),
            SizedBox(height: 14),
            Row(children: [
              Skeleton(width: 60, height: 14),
              SizedBox(width: 16),
              Skeleton(width: 40, height: 14),
              SizedBox(width: 16),
              Skeleton(width: 70, height: 14),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// Stand-in for the detail screen while it loads.
class PropertyDetailSkeleton extends StatelessWidget {
  const PropertyDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(physics: const NeverScrollableScrollPhysics(), children: const [
      SizedBox(height: 300, child: Skeleton(height: double.infinity, radius: 0)),
      Padding(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Skeleton(width: 160, height: 26),
          SizedBox(height: 14),
          Skeleton(width: 260, height: 18),
          SizedBox(height: 10),
          Skeleton(width: 180, height: 14),
          SizedBox(height: 22),
          Row(children: [
            Skeleton(width: 80, height: 32, radius: 16),
            SizedBox(width: 8),
            Skeleton(width: 80, height: 32, radius: 16),
            SizedBox(width: 8),
            Skeleton(width: 80, height: 32, radius: 16),
          ]),
          SizedBox(height: 26),
          Skeleton(height: 14),
          SizedBox(height: 8),
          Skeleton(height: 14),
          SizedBox(height: 8),
          Skeleton(width: 200, height: 14),
        ]),
      ),
    ]);
  }
}
