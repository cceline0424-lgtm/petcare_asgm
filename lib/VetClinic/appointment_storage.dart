import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppointmentStorage {
  static CollectionReference<Map<String, dynamic>> get _appointments =>
      FirebaseFirestore.instance.collection('appointments');

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static Future<void> saveAppointment(Map<String, dynamic> appointmentData) async {
    final uid = _uid;
    if (uid == null) return;

    final docRef = _appointments.doc();
    appointmentData['id'] = docRef.id;
    appointmentData['status'] = 'Upcoming';

    await docRef.set({
      ...appointmentData,
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<Map<String, dynamic>>> getAppointments() async {
    final uid = _uid;
    if (uid == null) return [];

    final snap = await _appointments.where('uid', isEqualTo: uid).get();

    final docs = snap.docs.toList()
      ..sort((a, b) {
        final aTime = a.data()['createdAt'] as Timestamp?;
        final bTime = b.data()['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return aTime.compareTo(bTime);
      });

    return docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data.remove('uid');
      data.remove('createdAt');
      return data;
    }).toList();
  }

  static Future<void> cancelAppointment(String id) async {
    await updateAppointmentStatus(id, 'Cancelled');
  }

  static Future<void> updateAppointmentStatus(String id, String status) async {
    await _appointments.doc(id).update({'status': status});
  }
}