import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/index.dart';

class NewsLinksWidget extends StatelessWidget {
  final List<NewsLink> links;

  const NewsLinksWidget({
    super.key,
    required this.links,
  });

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return Icons.thumb_up; // Facebook-like icon
      case 'twitter':
        return Icons.alternate_email; // Twitter/X icon
      case 'instagram':
        return Icons.camera_alt; // Instagram icon
      case 'youtube':
        return Icons.play_circle_filled;
      case 'linkedin':
        return Icons.business;
      case 'whatsapp':
        return Icons.chat;
      case 'telegram':
        return Icons.send;
      case 'other':
      default:
        return Icons.link;
    }
  }

  Color _getPlatformColor(String platform, ColorScheme colorScheme) {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return const Color(0xFF1877F2); // Facebook blue
      case 'twitter':
        return const Color(0xFF1DA1F2); // Twitter blue
      case 'instagram':
        return const Color(0xFFE4405F); // Instagram pink
      case 'youtube':
        return const Color(0xFFFF0000); // YouTube red
      case 'linkedin':
        return const Color(0xFF0077B5); // LinkedIn blue
      case 'whatsapp':
        return const Color(0xFF25D366); // WhatsApp green
      case 'telegram':
        return const Color(0xFF0088CC); // Telegram blue
      case 'other':
      default:
        return colorScheme.primary;
    }
  }

  Future<void> _launchUrl(String url, BuildContext context) async {
    try {
      // Ensure URL has a scheme
      String urlToLaunch = url;
      if (!urlToLaunch.startsWith('http://') && !urlToLaunch.startsWith('https://') &&
          !urlToLaunch.startsWith('tel:') && !urlToLaunch.startsWith('mailto:') &&
          !urlToLaunch.startsWith('sms:') && !urlToLaunch.startsWith('geo:')) {
        urlToLaunch = 'https://$urlToLaunch';
      }
      
      final uri = Uri.parse(urlToLaunch);
      
      // Try to launch directly first (works better on Android 11+ with queries)
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        if (!launched) {
          // If launch returned false, try with canLaunchUrl check
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not open link: $url'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        }
      } catch (e) {
        // If direct launch fails, try with canLaunchUrl
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Could not launch URL: $e');
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open link: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: links.map((link) {
        final icon = _getPlatformIcon(link.platform);
        final color = _getPlatformColor(link.platform, colorScheme);
        
        return InkWell(
          onTap: () => _launchUrl(link.url, context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  link.platform,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.open_in_new,
                  size: 12,
                  color: color.withOpacity(0.7),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

