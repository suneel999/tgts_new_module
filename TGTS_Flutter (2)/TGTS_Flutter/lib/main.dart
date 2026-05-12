import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'screens/mobile/splash_screen.dart';
import 'screens/mobile/otp_login_screen.dart';
import 'screens/mobile/language_selection_screen.dart';
import 'screens/mobile/main_navigation_screen.dart';
import 'screens/mobile/membership_screen.dart';
import 'screens/mobile/documents_screen.dart';
import 'screens/mobile/api_test_screen.dart';
import 'screens/mobile/news_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'models/index.dart';
import 'services/auth_service.dart';
import 'services/language_service.dart';
import 'utils/app_theme.dart';
import 'utils/timezone.dart';

void main() {
  // Initialize timezone data for IST support
  initializeTimezone();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LanguageService()),
      ],
      child: Consumer<AuthService>(
        builder: (context, authService, child) {
          return MaterialApp.router(
            title: 'Telangana Congress App',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            debugShowCheckedModeBanner: false,
            routerConfig: _router,
          );
        },
      ),
    );
  }

  final GoRouter _router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final isAuthenticated = authService.isAuthenticated;
      final hasMembership = authService.hasMembership;
      final isMembershipRoute = state.matchedLocation == '/membership';
      final isLoginRoute = state.matchedLocation == '/login';
      final isSplashRoute = state.matchedLocation == '/';
      final isLanguageRoute = state.matchedLocation == '/language';
      final isPublicRoute = isLoginRoute || isSplashRoute || isLanguageRoute || state.matchedLocation == '/api-test';
      
      // Define protected routes that require membership
      final isProtectedRoute = !isPublicRoute && !isMembershipRoute && !isLoginRoute;
      
      print('🛡️ Route Guard - location: ${state.matchedLocation}, authenticated: $isAuthenticated, hasMembership: $hasMembership, isProtected: $isProtectedRoute');
      
      // Allow public routes
      if (isPublicRoute) {
        print('🛡️ Route Guard - Public route, allowing');
        return null;
      }
      
      // If not authenticated, redirect to login
      if (!isAuthenticated) {
        print('🛡️ Route Guard - Not authenticated, redirecting to /login');
        return '/login';
      }
      
      // CRITICAL: If authenticated but no membership, MUST redirect to membership
      // This applies to ALL protected routes (home, media, events, documents, etc.)
      if (hasMembership == false) {
        if (isMembershipRoute) {
          print('🛡️ Route Guard - No membership but on /membership, allowing');
          return null; // Allow staying on membership page
        } else {
          print('🛡️ Route Guard - ❌ BLOCKED: No membership, redirecting to /membership from ${state.matchedLocation}');
          return '/membership';
        }
      }
      
      // If membership status is null and trying to access protected route, redirect to membership
      if (hasMembership == null && isProtectedRoute) {
        print('🛡️ Route Guard - Membership status null, redirecting to /membership to check');
        return '/membership';
      }
      
      // If has membership and trying to access membership page, redirect to home
      if (hasMembership == true && isMembershipRoute) {
        print('🛡️ Route Guard - Has membership but on membership page, redirecting to /home');
        return '/home';
      }
      
      print('🛡️ Route Guard - ✅ Allowing navigation to ${state.matchedLocation}');
      return null; // Allow navigation
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => OTPLoginScreen(
          onLogin: () {
            // Navigation is handled in the OTP login screen based on membership status
            // This callback is kept for compatibility but doesn't navigate
          },
        ),
      ),
      GoRoute(
        path: '/language',
        builder: (context, state) => LanguageSelectionScreen(
          currentLanguage: context.watch<LanguageService>().language,
          onSelectLanguage: (language) {
            context.read<LanguageService>().setLanguage(language);
          },
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => MainNavigationScreen(
          initialIndex: 0,
          userRole: UserRole.public,
        ),
      ),
      GoRoute(
        path: '/media',
        builder: (context, state) => MainNavigationScreen(
          initialIndex: 1,
          userRole: UserRole.public,
        ),
      ),
      GoRoute(
        path: '/events',
        builder: (context, state) => MainNavigationScreen(
          initialIndex: 2,
          userRole: UserRole.public,
        ),
      ),
      GoRoute(
        path: '/documents',
        builder: (context, state) => const DocumentsScreen(),
      ),
      GoRoute(
        path: '/news',
        builder: (context, state) => const NewsScreen(),
      ),
      GoRoute(
        path: '/membership',
        builder: (context, state) => const MembershipScreen(),
      ),
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => AdminDashboardScreen(
          language: context.watch<LanguageService>().language,
        ),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => UserManagementScreen(
          language: context.watch<LanguageService>().language,
        ),
      ),
      GoRoute(
        path: '/api-test',
        builder: (context, state) => const ApiTestScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Error: ${state.error}'),
      ),
    ),
  );
}