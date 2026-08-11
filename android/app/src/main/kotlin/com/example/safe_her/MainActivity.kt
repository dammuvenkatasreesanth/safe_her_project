package com.example.safe_her

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth (Evidence's biometric view-gate) requires a FragmentActivity
// host on Android — FlutterActivity alone doesn't support it.
class MainActivity : FlutterFragmentActivity()
