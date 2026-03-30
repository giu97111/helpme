import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePhotoService {
  static final _storage = FirebaseStorage.instance;

  /// Carica [file] in `profile_photos/{uid}/profile.jpg` e restituisce l'URL pubblico.
  static Future<String> uploadProfilePhoto(String uid, XFile file) async {
    final ref = _storage.ref().child('profile_photos/$uid/profile.jpg');
    final contentType = _contentType(file);
    final meta = SettableMetadata(contentType: contentType);

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await ref.putData(bytes, meta);
    } else {
      await ref.putFile(File(file.path), meta);
    }
    return ref.getDownloadURL();
  }

  static String _contentType(XFile file) {
    final n = file.name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
