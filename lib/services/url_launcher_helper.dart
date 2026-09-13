import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherHelper {
  /// Opens a URL in a new browser tab or external browser application.
  static Future<bool> openUrl(String url) async {
    if (url.trim().isEmpty) return false;

    String formattedUrl = url.trim();
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }

    try {
      final uri = Uri.parse(formattedUrl);
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
      } else {
        debugPrint('Could not launch URL: $formattedUrl');
        return false;
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      return false;
    }
  }

  /// Checks if a given string looks like an Amazon product link
  static bool isAmazonUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final clean = url.trim().toLowerCase();
    
    // Check with URI host or regex
    final amazonPattern = RegExp(r'^(https?:\/\/)?([a-z0-9-]+\.)*(amazon\.[a-z.]+|amzn\.to|amzn\.in|a\.co)(\/.*)?$', caseSensitive: false);
    return amazonPattern.hasMatch(clean);
  }

  /// Extracts a clean display label or ASIN from an Amazon URL
  static String formatAmazonUrlDisplay(String url) {
    if (url.isEmpty) return '';
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.contains('dp')) {
        final idx = uri.pathSegments.indexOf('dp');
        if (idx + 1 < uri.pathSegments.length) {
          return 'Amazon Item (${uri.pathSegments[idx + 1]})';
        }
      }
      return uri.host.isNotEmpty ? uri.host : 'amazon.com';
    } catch (_) {
      return 'Amazon Link';
    }
  }
}
