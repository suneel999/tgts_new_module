import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _version = 'V0.1.1';

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait for animation and initialization
    await Future.wait([
      _animationController.forward(),
      _initializeAuth(),
    ]);
    
    // Add a small delay before navigation for better UX
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.isAuthenticated) {
        // Check membership status
        try {
          final hasMembership = await authService.checkMembershipStatus()
              .timeout(const Duration(seconds: 10));
          
          if (!mounted) return;
          
          // Wait a bit for auth state to update
          await Future.delayed(const Duration(milliseconds: 100));
          
          // Navigate based on membership status
          if (hasMembership) {
            // User has membership, go to home
            context.go('/home');
          } else {
            // User doesn't have membership, go to membership page
            context.go('/membership');
          }
        } catch (e) {
          print('Error checking membership in splash: $e');
          // If membership check fails, check cached status
          if (mounted) {
            final hasMembership = authService.hasMembership;
            if (hasMembership == false) {
              context.go('/membership');
            } else {
              context.go('/home');
            }
          }
        }
      } else {
        context.go('/login');
      }
    }
  }

  Future<void> _initializeAuth() async {
    if (mounted) {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.initialize();
    }
  }

  Future<void> _loadVersionInfo() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = 'V${packageInfo.version}';
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Tricolor gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFF9933), // Saffron
                  Colors.white,      // White
                  Color(0xFF138808), // Green
                ],
              ),
            ),
          ),
          // Content with fade-in animation
          Align(
            alignment: const Alignment(0, -0.25),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // White circle with navy border & orange icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Color(0xFF000080), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/INC_Logo_SplashScreen.jpg',
                        width: 94,
                        height: 94,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Telangana Congress',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'తెలంగాణ కాంగ్రెస్',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.favorite, color: Color(0xFFFF9933), size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Connecting Party & People',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Header image centered on the screen
          Align(
            alignment: const Alignment(0, 0.5),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Image.asset(
                'assets/images/header.png',
                width: double.infinity,
                fit: BoxFit.fitWidth,
                alignment: Alignment.center,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
          // Version number above the header image
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                _version,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87.withValues(alpha: 0.7),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
