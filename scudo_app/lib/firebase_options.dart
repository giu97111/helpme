// Opzioni Firebase allineate a google-services.json / GoogleService-Info.plist (helpme-c8755).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'Configura Firebase per macOS con flutterfire configure.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions non supportate per questa piattaforma.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDxM-WaBwICVGPcFw7aTkka_rhyb7MZCzw',
    appId: '1:370603378201:android:9f030aca86bf6eeac88c88',
    messagingSenderId: '370603378201',
    projectId: 'helpme-c8755',
    storageBucket: 'helpme-c8755.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCuc-MACrKAZVLg-0q8rNB-6G44R5fUY24',
    appId: '1:370603378201:ios:6db5d8dd30ecd493c88c88',
    messagingSenderId: '370603378201',
    projectId: 'helpme-c8755',
    storageBucket: 'helpme-c8755.firebasestorage.app',
    iosBundleId: 'com.gio.hempme',
  );

  /// Aggiungi un'app Web nel progetto Firebase e sostituisci [appId].
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDxM-WaBwICVGPcFw7aTkka_rhyb7MZCzw',
    appId: '1:370603378201:web:0000000000000000000000',
    messagingSenderId: '370603378201',
    projectId: 'helpme-c8755',
    storageBucket: 'helpme-c8755.firebasestorage.app',
  );
}
