import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // A getter rather than a field, so creating an AuthService doesn't touch
  // Firebase until a method is called (widget tests don't initialize Firebase).
  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<UserCredential> signIn({
    required String email, 
    required String password
    } )async {
      return await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> createAccount({
    required String email, 
    required String password
    } )async {
      return await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<void> resetPassword({
    required String email,
  }) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> updateUsername({
    required String username 
    } )async {
      await currentUser!.updateDisplayName(username);
  }

  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    AuthCredential credential = EmailAuthProvider.credential(email: email, password: password);
    await currentUser!.reauthenticateWithCredential(credential);
    //implement delete user uploaded data first
    await currentUser!.delete();
    await _firebaseAuth.signOut();
  }
}