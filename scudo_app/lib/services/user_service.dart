import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class UserService {
  static final _db = FirebaseFirestore.instance;

  static String _displayName(User user) {
    final n = user.displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'Utente';
  }

  static Future<void> syncProfile(User user, {String? fcmToken}) async {
    await _db.collection('users').doc(user.uid).set({
      'email': user.email,
      'displayName': _displayName(user),
      'photoUrl': user.photoURL,
      'fcmToken': ?fcmToken,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> userDocStream(
    String uid,
  ) {
    return _db.collection('users').doc(uid).snapshots();
  }

  /// Nome per la UI: prima `users.displayName` (Firestore), poi Auth, poi parte locale email.
  static String resolveDisplayName(
    User user,
    Map<String, dynamic>? firestoreData,
  ) {
    final fromFs = firestoreData?['displayName'] as String?;
    if (fromFs != null && fromFs.trim().isNotEmpty) return fromFs.trim();
    final fromAuth = user.displayName?.trim();
    if (fromAuth != null && fromAuth.isNotEmpty) return fromAuth;
    final email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return '';
  }

  /// Una lettura Firestore + stessa logica di [resolveDisplayName] (es. allarme SOS).
  static Future<String> getResolvedDisplayName(User user) async {
    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      final s = resolveDisplayName(user, doc.data());
      if (s.isNotEmpty) return s;
    } catch (_) {}
    return resolveDisplayName(user, null);
  }

  /// URL foto profilo: solo per il proprio uid (le regole Firestore non espongono altri profili).
  static Future<String?> getUserPhotoUrl(String uid) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || u.uid != uid) return null;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final url = doc.data()?['photoUrl'] as String?;
      if (url != null && url.isNotEmpty) return url;
    } catch (_) {}
    return u.photoURL;
  }

  static Future<void> updateLocation(String uid, Position pos) async {
    await _db.collection('users').doc(uid).set({
      'lastLat': pos.latitude,
      'lastLng': pos.longitude,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> updateFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).set({
      'fcmToken': token,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Conteggio utenti tramite Cloud Function (il count client su `users` non è più consentito dalle regole).
  static Future<int> countUsers() async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('getPublicUserCount');
      final result =
          await callable.call().timeout(const Duration(seconds: 15));
      final data = result.data;
      if (data is Map) {
        final c = data['count'];
        if (c is int) return c;
        if (c is num) return c.toInt();
      }
      return 0;
    } on TimeoutException {
      return 0;
    } catch (_) {
      return 0;
    }
  }
}
