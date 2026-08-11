import 'package:connectivity_plus/connectivity_plus.dart';
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

  /// Opens the device's native SMS composer pre-filled with [message] for
  /// [phone] — the "SMS Fallback" path, since it needs no data connection
  /// at all (unlike WhatsApp/Firestore). The user still taps Send, same as
  /// the WhatsApp flow; there's no SMS gateway/backend in this app.
  static Future<bool> sendSms(String phone, String message) async {
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  /// Opens the phone dialer with [phone] pre-filled and initiates the call
  /// — used by the SOS screen's direct-call actions (Police/Ambulance/
  /// contacts). Returns false (instead of throwing) if the dialer couldn't
  /// be opened.
  static Future<bool> callNumber(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.trim());
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  /// True when the device has no network path at all (airplane mode, no
  /// signal, wifi/data both off) — the condition the "SMS Fallback" setting
  /// cares about, since SMS doesn't need data connectivity to send.
  static Future<bool> hasNoConnection() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.every((r) => r == ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

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
