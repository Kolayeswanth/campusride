import 'package:flutter/material.dart';

/// A page route that fades in the destination page.
class FadeInPageRoute<T> extends PageRouteBuilder<T> {
  /// The page to navigate to.
  final Widget page;
  
  /// The duration of the transition animation.
  final Duration duration;

  /// Creates a route that fades in [page].
  FadeInPageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 300),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var curve = Curves.easeInOut;
            var curveTween = CurveTween(curve: curve);
            var fadeAnimation = animation.drive(curveTween);
            
            return FadeTransition(
              opacity: fadeAnimation,
              child: child,
            );
          },
          transitionDuration: duration,
        );
}

/// A page route that slides in the destination page from the bottom.
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  /// The page to navigate to.
  final Widget page;
  
  /// The duration of the transition animation.
  final Duration duration;

  /// Creates a route that slides up [page].
  SlideUpPageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 300),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var curve = Curves.easeInOut;
            var curveTween = CurveTween(curve: curve);
            var fadeAnimation = animation.drive(curveTween);
            
            var begin = const Offset(0.0, 0.2);
            var end = Offset.zero;
            var tween = Tween(begin: begin, end: end).chain(curveTween);
            var offsetAnimation = animation.drive(tween);
            
            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: child,
              ),
            );
          },
          transitionDuration: duration,
        );
}

/// A custom navigation helper to provide animated page transitions.
class AnimatedNavigation {
  /// Navigate to a page with a fade transition.
  static Future<T?> fadeIn<T>(
    BuildContext context, 
    Widget page, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Navigator.of(context).push<T>(
      FadeInPageRoute<T>(
        page: page,
        duration: duration,
      ),
    );
  }
  
  /// Navigate to a page with a slide up transition.
  static Future<T?> slideUp<T>(
    BuildContext context, 
    Widget page, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Navigator.of(context).push<T>(
      SlideUpPageRoute<T>(
        page: page,
        duration: duration,
      ),
    );
  }
  
  /// Replace the current route with a new page using a fade transition.
  static Future<T?> fadeInReplacement<T>(
    BuildContext context, 
    Widget page, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Navigator.of(context).pushReplacement(
      FadeInPageRoute<T>(
        page: page,
        duration: duration,
      ),
    );
  }
  
  /// Replace the current route with a new page using a slide up transition.
  static Future<T?> slideUpReplacement<T>(
    BuildContext context, 
    Widget page, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Navigator.of(context).pushReplacement(
      SlideUpPageRoute<T>(
        page: page,
        duration: duration,
      ),
    );
  }
  
  /// Remove all existing routes and navigate to a new page with a fade transition.
  static Future<T?> fadeInAndRemoveUntil<T>(
    BuildContext context, 
    Widget page, {
    bool Function(Route<dynamic>)? predicate,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Navigator.of(context).pushAndRemoveUntil<T>(
      FadeInPageRoute<T>(
        page: page,
        duration: duration,
      ),
      predicate ?? (route) => false,
    );
  }
  
  /// Remove all existing routes and navigate to a new page with a slide up transition.
  static Future<T?> slideUpAndRemoveUntil<T>(
    BuildContext context, 
    Widget page, {
    bool Function(Route<dynamic>)? predicate,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Navigator.of(context).pushAndRemoveUntil<T>(
      SlideUpPageRoute<T>(
        page: page,
        duration: duration,
      ),
      predicate ?? (route) => false,
    );
  }
} 