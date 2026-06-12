import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_page.dart';
import 'home_screen.dart';
import 'admin_features/admin_homePage.dart';

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
      title: 'CarBure',
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
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) {
        Widget nextScreen;
        if (isLoggedIn) {
          final employeeId = prefs.getString('employeeId') ?? '';
          if (employeeId.toUpperCase() == 'ADMIN001') {
            nextScreen = const AdminHomePage();
          } else {
            nextScreen = HomeScreen(
              loginId: prefs.getString('loginId') ?? '',
              permissions: prefs.getString('permissions') ?? '',
              accessPermissions: prefs.getString('accessPermissions') ?? '',
              role: prefs.getString('role') ?? 'Member',
              assignedSheet: prefs.getString('assignedSheet') ?? '',
            );
          }
        } else {
          nextScreen = const LoginPage();
        }

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 1000),
            pageBuilder: (_, _, _) => nextScreen,
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF0F172A,
      ), // Deep aesthetic dark background
      body: Center(
        child:
            Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white, // Ensure pure circular mask
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/logo.png',
                      width: 250, // Adjusted size for a circular profile
                      height: 250,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      isAntiAlias: true,
                    ),
                  ),
                )
                .animate()
                // 1. Initial snap fade-in from the darkness
                .fadeIn(duration: 400.ms, curve: Curves.easeOutExpo)
                // 2. Initial dramatic scale up to "settle" the logo
                .scale(
                  begin: const Offset(0.4, 0.4),
                  end: const Offset(1.0, 1.0),
                  duration: 600.ms,
                  curve: Curves.easeOutBack,
                )
                // 3. The blinding flare / shimmer passing through the logo
                .shimmer(
                  delay: 400.ms,
                  duration: 800.ms,
                  color: Colors.white.withValues(
                    alpha: 0.6,
                  ), // Soften the shimmer
                  angle: 1.2,
                  size: 3.0,
                  // Removed BlendMode.screen which causes the square artifact
                )
                // 4. A very subtle rumble/shake (the bass drop moment)
                .shake(
                  delay: 1100.ms,
                  duration: 200.ms,
                  hz: 8,
                  curve: Curves.easeInOut,
                  offset: const Offset(2, 2),
                )
                // 5. The Netflix Boom: Massive exponential zoom towards the camera
                .scale(
                  delay: 1300.ms,
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(12.0, 12.0), // Extreme zoom
                  duration: 1500.ms,
                  curve: Curves.easeInExpo, // Accelerates violently at the end
                )
                // 6. Intense motion blur as it flies past the camera lens
                .blur(
                  delay: 2000.ms,
                  duration: 800.ms,
                  begin: const Offset(0, 0),
                  end: const Offset(30, 30),
                  curve: Curves.easeIn,
                )
                // 7. Fade to pure darkness exactly as the route transitions (at 2.8s)
                .fadeOut(
                  delay: 2300.ms,
                  duration: 500.ms,
                  curve: Curves.easeOutQuad,
                ),
      ),
    );
  }
}
