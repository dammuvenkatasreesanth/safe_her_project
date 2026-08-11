import 'package:local_auth/local_auth.dart';

/// Gates viewing evidence behind the device's own lock (Module 7 — "the
/// user must use their phone's biometric/lock to see the evidence").
/// `biometricOnly: false` lets `local_auth` fall back to PIN/pattern/
/// password when biometrics aren't enrolled, so this never locks someone
/// out of their own evidence just because they haven't set up a fingerprint.
class BiometricService {
  BiometricService._();

  static final _auth = LocalAuthentication();

  /// Whether this device can authenticate at all (biometric or device
  /// credential) — used to skip the gate gracefully rather than block
  /// evidence forever on hardware that doesn't support it.
  static Future<bool> canAuthenticate() async {
    try {
      final deviceSupported = await _auth.isDeviceSupported();
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      return deviceSupported || canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Prompts for biometric/device-credential auth. Returns true only on a
  /// real success — every failure mode (no hardware, user cancelled,
  /// locked out) comes back as false rather than throwing, since the
  /// caller's response is the same either way: don't show the evidence.
  static Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
