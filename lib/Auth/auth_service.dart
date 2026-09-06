import 'package:firebase_auth/firebase_auth.dart';
import 'database_helper.dart';

class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static Future<bool> isLoggedIn() async => _auth.currentUser != null;
  static Future<String?> getLoggedInUsername() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName;
    }

    final profile = await DatabaseHelper.instance.getUserByUid(user.uid);
    return profile?['username'] as String?;
  }

  static Future<void> logout() => _auth.signOut();
}