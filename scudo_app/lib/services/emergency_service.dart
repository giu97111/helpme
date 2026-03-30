import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class EmergencyService {
  static final _col = FirebaseFirestore.instance.collection('emergencies');

  static Future<String> startEmergency({
    required String userId,
    required String displayName,
    required Position pos,
    String? photoUrl,
  }) async {
    final data = <String, dynamic>{
      'userId': userId,
      'displayName': displayName,
      'status': 'active',
      'lat': pos.latitude,
      'lng': pos.longitude,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (photoUrl != null && photoUrl.isNotEmpty) {
      data['photoUrl'] = photoUrl;
    }
    final doc = await _col.add(data);
    return doc.id;
  }

  static Future<void> updateLocation(String emergencyId, Position pos) async {
    await _col.doc(emergencyId).update({
      'lat': pos.latitude,
      'lng': pos.longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> resolve(String emergencyId) async {
    await _col.doc(emergencyId).update({
      'status': 'resolved',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> getEmergencyOnce(
    String emergencyId,
  ) {
    return _col.doc(emergencyId).get();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> emergencyStream(
    String emergencyId,
  ) {
    return _col.doc(emergencyId).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> activeEmergenciesStream() {
    return _col.where('status', isEqualTo: 'active').snapshots();
  }

  /// Se valorizzato, l’utente è sulla schermata SOS propria ([SosActiveScreen]):
  /// le notifiche verso la mappa di un altro allarme non devono sostituirla.
  static String? ownSosUiEmergencyId;

  static void registerOwnSosUi(String emergencyId) {
    ownSosUiEmergencyId = emergencyId;
  }

  static void unregisterOwnSosUi(String emergencyId) {
    if (ownSosUiEmergencyId == emergencyId) {
      ownSosUiEmergencyId = null;
    }
  }
}
