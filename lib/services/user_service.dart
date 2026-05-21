import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class UserService {
  static final _db = FirebaseFirestore.instance;

  static Stream<UserModel?> currentProfileStream() {
    final uid = AuthService.currentUid;
    if (uid.isEmpty) return Stream.value(null);
    return _db.collection('users').doc(uid).snapshots().map(
      (doc) => doc.exists ? UserModel.fromFirestore(doc) : null,
    );
  }

  static Future<UserModel?> getCurrentProfile() async {
    final uid = AuthService.currentUid;
    if (uid.isEmpty) return null;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  static Future<UserModel?> getProfile(String uid) async {
    if (uid.isEmpty) return null;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  static Future<void> saveNickname(String nickname) async {
    final uid = AuthService.currentUid;
    if (uid.isEmpty) return;
    await _db.collection('users').doc(uid).set({
      'nickname': nickname,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<String?> uploadAvatar(File file) async {
    final uid = AuthService.currentUid;
    if (uid.isEmpty) return null;
    final dir = await getTemporaryDirectory();
    final targetPath = '${dir.path}/avatar_$uid.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80,
      minWidth: 256,
      minHeight: 256,
    );
    final uploadFile = compressed != null ? File(compressed.path) : file;
    final ref = FirebaseStorage.instance.ref().child('avatars/$uid.jpg');
    await ref.putFile(uploadFile);
    final url = await ref.getDownloadURL();
    await _db.collection('users').doc(uid).update({'avatarUrl': url});
    return url;
  }
}
