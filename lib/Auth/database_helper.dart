import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String username,
    required String email,
    required String phone,
  }) async {
    await _users.doc(uid).set({
      'name': name,
      'username': username,
      'email': email,
      'phone': phone,
    });
  }

  Future<int> updateUserProfile(String username, String name, String email, String phone) async {
    final existing = await getUserByUsername(username);
    if (existing == null) return 0;

    final emailOwner = await getUserByEmail(email);
    if (emailOwner != null && emailOwner['uid'] != existing['uid']) {
      throw Exception('Email is already in use by another account.');
    }

    final phoneOwner = await getUserByPhone(phone);
    if (phoneOwner != null && phoneOwner['uid'] != existing['uid']) {
      throw Exception('Phone is already in use by another account.');
    }

    await _users.doc(existing['uid'] as String).update({
      'name': name,
      'email': email,
      'phone': phone,
    });
    return 1;
  }

  Future<Map<String, dynamic>?> getUserByUid(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['uid'] = doc.id;
    return data;
  }

  Future<Map<String, dynamic>?> _firstWhere(String field, String value) async {
    final snap = await _users.where(field, isEqualTo: value).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data();
    data['uid'] = snap.docs.first.id;
    return data;
  }

  Future<Map<String, dynamic>?> getUserByUsername(String username) => _firstWhere('username', username);
  Future<Map<String, dynamic>?> getUserByEmail(String email) => _firstWhere('email', email);
  Future<Map<String, dynamic>?> getUserByPhone(String phone) => _firstWhere('phone', phone);

  Future<bool> isUsernameTaken(String username) async => await getUserByUsername(username) != null;
  Future<bool> isEmailTaken(String email) async => await getUserByEmail(email) != null;
  Future<bool> isPhoneTaken(String phone) async => await getUserByPhone(phone) != null;
}