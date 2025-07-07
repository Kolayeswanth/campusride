import 'package:flutter/material.dart';

/// A widget that applies a pulse animation to its child.
class PulseAnimation extends StatefulWidget {
  /// The child widget to animate.
  final Widget child;

  /// Whether the animation is active.
  final bool isActive;

  /// The maximum scale factor of the pulse.
  final double maxScale;

  /// The minimum scale factor of the pulse.
  final double minScale;

  /// The duration of one pulse cycle.
  final Duration duration;

  /// The curve of the animation.
  final Curve curve;

  /// Creates a PulseAnimation.
  const PulseAnimation({
    Key? key,
    required this.child,
    this.isActive = true,
    this.maxScale = 1.05,
    this.minScale = 0.95,
    this.duration = const Duration(milliseconds: 1500),
    this.curve = Curves.easeInOut,
  }) : super(key: key);

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _setUpAnimation();

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  void _setUpAnimation() {
    _animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: widget.maxScale,
        ).chain(CurveTween(curve: widget.curve)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: widget.maxScale,
          end: widget.minScale,
        ).chain(CurveTween(curve: widget.curve)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(PulseAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }

    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }

    if (widget.maxScale != oldWidget.maxScale ||
        widget.minScale != oldWidget.minScale ||
        widget.curve != oldWidget.curve) {
      _setUpAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Transform.scale(
        scale: _animation.value,
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// A widget that applies a fade pulse animation to its child.
class FadePulseAnimation extends StatefulWidget {
  /// The child widget to animate.
  final Widget child;

  /// Whether the animation is active.
  final bool isActive;

  /// The maximum opacity of the pulse.
  final double maxOpacity;

  /// The minimum opacity of the pulse.
  final double minOpacity;

  /// The duration of one pulse cycle.
  final Duration duration;

  /// The curve of the animation.
  final Curve curve;

  /// Creates a FadePulseAnimation.
  const FadePulseAnimation({
    Key? key,
    required this.child,
    this.isActive = true,
    this.maxOpacity = 1.0,
    this.minOpacity = 0.7,
    this.duration = const Duration(milliseconds: 1500),
    this.curve = Curves.easeInOut,
  }) : super(key: key);

  @override
  State<FadePulseAnimation> createState() => _FadePulseAnimationState();
}

class _FadePulseAnimationState extends State<FadePulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _setUpAnimation();

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  void _setUpAnimation() {
    _animation = Tween<double>(
      begin: widget.maxOpacity,
      end: widget.minOpacity,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ),
    );
  }

  @override
  void didUpdateWidget(FadePulseAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }

    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }

    if (widget.maxOpacity != oldWidget.maxOpacity ||
        widget.minOpacity != oldWidget.minOpacity ||
        widget.curve != oldWidget.curve) {
      _setUpAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Opacity(
        opacity: _animation.value,
        child: child,
      ),
      child: widget.child,
    );
  }
}
