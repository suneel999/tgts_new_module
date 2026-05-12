// import 'package:flutter/material.dart';
// import '../../models/index.dart';
// import '../../widgets/mobile_nav_bar.dart';
// import 'mobile_home_screen.dart';
// import 'media_gallery_screen.dart';
// import 'events_screen.dart';
// import 'documents_screen.dart';
// import 'profile_screen.dart';
//
// class MainNavigationScreen extends StatefulWidget {
//   final int initialIndex;
//   final UserRole userRole;
//
//   const MainNavigationScreen({
//     Key? key,
//     this.initialIndex = 0,
//     required this.userRole,
//   }) : super(key: key);
//
//   @override
//   State<MainNavigationScreen> createState() => _MainNavigationScreenState();
// }
//
// class _MainNavigationScreenState extends State<MainNavigationScreen> {
//   late int _currentIndex;
//   late PageController _pageController;
//
//   @override
//   void initState() {
//     super.initState();
//     _currentIndex = widget.initialIndex;
//     _pageController = PageController(initialPage: _currentIndex);
//   }
//
//   @override
//   void dispose() {
//     _pageController.dispose();
//     super.dispose();
//   }
//
//   void _onTabTapped(int index) {
//     if (index <= 4) {
//       setState(() {
//         _currentIndex = index;
//       });
//       _pageController.animateToPage(
//         index,
//         duration: const Duration(milliseconds: 300),
//         curve: Curves.easeInOut,
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: PageView(
//         controller: _pageController,
//         onPageChanged: (index) {
//           setState(() {
//             _currentIndex = index;
//           });
//         },
//         children: [
//           MobileHomeScreen(
//             userRole: widget.userRole,
//             onTabChange: _onTabTapped,
//           ),
//           const MediaGalleryScreen(),
//           const EventsScreen(),
//           const DocumentsScreen(),
//           const ProfileScreen(),
//         ],
//       ),
//       bottomNavigationBar: MobileNavBar(
//         currentIndex: _currentIndex,
//         onTap: _onTabTapped,
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import '../../models/index.dart';
import '../../widgets/mobile_nav_bar.dart';
import 'mobile_home_screen.dart';
import 'media_gallery_screen.dart';
import 'events_screen.dart';
import 'my_activity_screen.dart';
import 'voter_mapping_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  final UserRole userRole;

  const MainNavigationScreen({
    Key? key,
    this.initialIndex = 0,
    required this.userRole,
  }) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index <= 5) {                         // ← updated from 4 to 5
      setState(() {
        _currentIndex = index;
      });
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: [
          MobileHomeScreen(
            userRole: widget.userRole,
            onTabChange: _onTabTapped,
          ),
          const MediaGalleryScreen(),
          const EventsScreen(),
          const MyActivityScreen(),
          const VoterMappingScreen(),
          const ProfileScreen(),             // ← Profile moved to index 5
        ],
      ),
      bottomNavigationBar: MobileNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}