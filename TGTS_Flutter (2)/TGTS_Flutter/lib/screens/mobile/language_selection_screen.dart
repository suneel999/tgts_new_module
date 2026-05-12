import 'package:flutter/material.dart';
import '../../models/index.dart';
import '../../utils/app_colors.dart';

class LanguageSelectionScreen extends StatefulWidget {
  final Language currentLanguage;
  final Function(Language) onSelectLanguage;

  const LanguageSelectionScreen({
    Key? key,
    required this.currentLanguage,
    required this.onSelectLanguage,
  }) : super(key: key);

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.currentLanguage == Language.en ? 'Language' : 'భాష',
          style: const TextStyle(color: Colors.black),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              widget.currentLanguage == Language.en
                  ? 'Select Language'
                  : 'భాషను ఎంచుకోండి',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.currentLanguage == Language.en
                  ? 'Choose your preferred language'
                  : 'మీకు ఇష్టమైన భాషను ఎంచుకోండి',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 40),
            _buildLanguageOption(
              Language.en,
              'English',
              'English',
              Icons.language,
            ),
            const SizedBox(height: 20),
            _buildLanguageOption(
              Language.te,
              'తెలుగు',
              'Telugu',
              Icons.language,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    Language language,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = widget.currentLanguage == language;
    
    return GestureDetector(
      onTap: () {
        widget.onSelectLanguage(language);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight.withOpacity(0.2) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 30,
              color: isSelected ? AppColors.primary : Colors.grey[600],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
