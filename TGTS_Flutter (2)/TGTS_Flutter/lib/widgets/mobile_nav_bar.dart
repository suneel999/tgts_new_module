// import 'package:flutter/material.dart';
// import '../models/index.dart';
// import '../utils/lang_ext.dart';
// import '../utils/app_colors.dart';
//
// class MobileNavBar extends StatelessWidget {
//   final int currentIndex;
//   final Function(int) onTap;
//
//   const MobileNavBar({
//     Key? key,
//     required this.currentIndex,
//     required this.onTap,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     final lang = context.lang;
//     return BottomNavigationBar(
//       currentIndex: currentIndex,
//       onTap: onTap,
//       type: BottomNavigationBarType.fixed,
//       backgroundColor: Colors.white,
//       selectedItemColor: AppColors.primary,
//       unselectedItemColor: Colors.grey[600],
//       elevation: 8,
//       items: [
//         BottomNavigationBarItem(
//           icon: const Icon(Icons.home),
//           label: lang == Language.en ? 'Home' : 'హోమ్',
//         ),
//         BottomNavigationBarItem(
//           icon: const Icon(Icons.photo_library),
//           label: lang == Language.en ? 'Media' : 'మీడియా',
//         ),
//         BottomNavigationBarItem(
//           icon: const Icon(Icons.event),
//           label: lang == Language.en ? 'Events' : 'కార్యక్రమాలు',
//         ),
//         BottomNavigationBarItem(
//           icon: const Icon(Icons.folder),
//           label: lang == Language.en ? 'Documents' : 'పత్రాలు',
//         ),
//         BottomNavigationBarItem(
//           icon: const Icon(Icons.person),
//           label: lang == Language.en ? 'Profile' : 'ప్రొఫైల్',
//         ),
//       ],
//     );
//   }
// }

import 'package:flutter/material.dart';
import '../models/index.dart';
import '../utils/lang_ext.dart';
import '../utils/app_colors.dart';

class MobileNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const MobileNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.grey[600],
      selectedFontSize: 11,
      unselectedFontSize: 10,
      elevation: 8,
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home),
          label: lang == Language.en ? 'Home' : 'హోమ్',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.photo_library),
          label: lang == Language.en ? 'Media' : 'మీడియా',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.event),
          label: lang == Language.en ? 'Events' : 'కార్యక్రమాలు',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.assignment_outlined),
          activeIcon: const Icon(Icons.assignment),
          label: lang == Language.en ? 'My Activity' : 'నా కార్యకలాపాలు',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.how_to_vote_outlined),
          activeIcon: const Icon(Icons.how_to_vote),
          label: lang == Language.en ? 'Voter Map' : 'ఓటరు మ్యాప్',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.person),
          label: lang == Language.en ? 'Profile' : 'ప్రొఫైల్',
        ),
      ],
    );
  }
}
