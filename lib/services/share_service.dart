import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Builds and launches location-sharing messages via WhatsApp or the
/// generic OS share sheet. No backend/SMS gateway exists in this app —
/// WhatsApp links only pre-fill a chat, the user still taps Send.
class ShareService {
  ShareService._();

  /// wa.me wants digits only, no '+', spaces, or dashes.
  static String sanitizePhoneForWhatsApp(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Opens WhatsApp with [message] pre-filled for [phone]. Returns false
  /// (instead of throwing) if WhatsApp/a browser couldn't be launched —
  /// callers should surface that to the user rather than assume delivery.
  static Future<bool> openWhatsApp(String phone, String message) async {
    final uri = Uri.https('wa.me', '/${sanitizePhoneForWhatsApp(phone)}', {
      'text': message,
    });
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Hands [message] to the OS share sheet (WhatsApp, SMS, email, etc.).
  static void shareViaOtherApps(String message) => Share.share(message);

  /// A plain "here's my current location" message with a maps pin link —
  /// used wherever there's no live SafeHer tracking session behind it.
  static String buildLocationMessage(LatLng location, {String? note}) {
    final link =
        'https://maps.google.com/?q=${location.latitude},${location.longitude}';
    final prefix = (note != null && note.trim().isNotEmpty)
        ? '${note.trim()}\n'
        : '';
    return '${prefix}Here is my current location: $link';
  }

  /// The live-trip message used by Live Tracking's share sheet, backed by
  /// a real Firestore session and its web tracking link.
  static String buildTripMessage({
    required String destination,
    String? vehicleNumber,
    required String sessionId,
  }) {
    final link = 'https://safeher.app/track/$sessionId';
    final vehicle = vehicleNumber ?? 'N/A';
    return 'I am sharing my live trip to $destination via SafeHer.\n'
        'Vehicle: $vehicle\n'
        'Track here: $link\n'
        '(Note: Web viewer coming soon, please open in SafeHer app)';
  }
}
