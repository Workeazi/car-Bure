import 'package:flutter/material.dart';
import 'login_page.dart';

void main() {
  runApp(const MyApp());
}

class ButterySmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const ButterySmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation.drive(
        Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
      ),
      child: SlideTransition(
        position: animation.drive(
          Tween(
            begin: const Offset(0.0, 0.04),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutQuint)),
        ),
        child: child,
      ),
    );
  }
}

class ButterySmoothScrollBehavior extends ScrollBehavior {
  const ButterySmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WorkEazi',
      scrollBehavior: const ButterySmoothScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF667EEA),
          primary: const Color(0xFF667EEA),
          secondary: const Color(0xFF764BA2),
          surface: const Color(0xFFF8F9FA),
        ),
        fontFamily: 'Roboto',
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ButterySmoothPageTransitionsBuilder(),
            TargetPlatform.iOS: ButterySmoothPageTransitionsBuilder(),
            TargetPlatform.windows: ButterySmoothPageTransitionsBuilder(),
            TargetPlatform.macOS: ButterySmoothPageTransitionsBuilder(),
            TargetPlatform.linux: ButterySmoothPageTransitionsBuilder(),
          },
        ),
      ),
      home: const LoginPage(),
    );
  }
}
