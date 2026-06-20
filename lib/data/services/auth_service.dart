import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';
import '../../core/utils/id_generator.dart';
import 'subscription_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _rememberMeKey = 'remember_me';
  static const String _savedEmailKey = 'saved_email';

  // ─── STREAM ──────────────────────────────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ─── LOGIN ───────────────────────────────────────────────────────────────────
  Future<UserModel> loginWithEmail({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Sačuvaj email ako je Remember Me
      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setBool(_rememberMeKey, true);
        await prefs.setString(_savedEmailKey, email.trim());
      } else {
        await prefs.remove(_rememberMeKey);
        await prefs.remove(_savedEmailKey);
      }

      final userModel = await _getUserFromFirestore(credential.user!.uid);

      // Provera da li je korisnik aktivan
      if (!userModel.activeStatus) {
        await _auth.signOut();
        throw AuthException(
          code: 'account-disabled',
          message: 'Vaš nalog nije povezan sa firmom ili je deaktiviran.',
        );
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  // ─── BIOMETRIC LOGIN ─────────────────────────────────────────────────────────
  Future<bool> authenticateWithBiometrics() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!isAvailable || !isDeviceSupported) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Prijavite se na Shiftio',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  // ─── REGISTER EMPLOYER ───────────────────────────────────────────────────────
  Future<UserModel> registerEmployer({
    required String name,
    required String surname,
    required String email,
    required String phone,
    required String password,
    required String companyName,
    DateTime? birthDate,
  }) async {
    try {
      // Kreiraj Firebase Auth nalog
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;

      // Generiši company ID
      final companyId = _firestore.collection('companies').doc().id;
      final inviteCode = IdGenerator.generateCompanyId();

      // Kreiraj kompaniju
      final company = CompanyModel(
        companyId: companyId,
        ownerId: uid,
        name: companyName.trim(),
        inviteCode: inviteCode,
        createdAt: DateTime.now(),
      );

      // Kreiraj korisnika
      final user = UserModel(
        uid: uid,
        name: name.trim(),
        surname: surname.trim(),
        email: email.trim(),
        phone: phone.trim(),
        role: UserRole.admin,
        currentCompanyId: companyId,
        vacationDays: 20,
        activeStatus: true,
        createdAt: DateTime.now(),
        birthDate: birthDate,
      );

      // Batch write - atomarna operacija
      final batch = _firestore.batch();
      batch.set(_firestore.collection('companies').doc(companyId), company.toFirestore());
      batch.set(_firestore.collection('users').doc(uid), user.toFirestore());
      await batch.commit();

      // Kreiraj Free tier pretplatu za novu firmu
      await SubscriptionService().createFreeTier(companyId);

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  // ─── VALIDATE COMPANY CODE ───────────────────────────────────────────────────
  Future<CompanyModel?> validateCompanyCode(String inviteCode) async {
    try {
      final code = inviteCode.trim().toUpperCase();
      if (code.isEmpty) return null;

      final query = await _firestore
          .collection('companies')
          .where('invite_code', isEqualTo: code)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      return CompanyModel.fromFirestore(query.docs.first);
    } catch (e) {
      return null;
    }
  }

  // ─── REGISTER WORKER ─────────────────────────────────────────────────────────
  Future<UserModel> registerWorker({
    required String name,
    required String surname,
    required String email,
    required String phone,
    required String password,
    required String companyId,
    DateTime? birthDate,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;

      final user = UserModel(
        uid: uid,
        name: name.trim(),
        surname: surname.trim(),
        email: email.trim(),
        phone: phone.trim(),
        role: UserRole.worker,
        currentCompanyId: companyId,
        vacationDays: 20,
        activeStatus: true,
        createdAt: DateTime.now(),
        birthDate: birthDate,
      );

      await _firestore.collection('users').doc(uid).set(user.toFirestore());

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  // ─── LOGOUT ──────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _auth.signOut();
  }

  // ─── RESET PASSWORD ──────────────────────────────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  // ─── GET USER ────────────────────────────────────────────────────────────────
  Future<UserModel> _getUserFromFirestore(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      throw AuthException(
        code: 'user-not-found',
        message: 'Korisnički profil nije pronađen.',
      );
    }
    return UserModel.fromFirestore(doc);
  }

  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      return await _getUserFromFirestore(user.uid);
    } catch (_) {
      return null;
    }
  }

  // ─── REMEMBER ME ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getSavedLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'rememberMe': prefs.getBool(_rememberMeKey) ?? false,
      'email': prefs.getString(_savedEmailKey) ?? '',
    };
  }

  // ─── ERROR HANDLER ───────────────────────────────────────────────────────────
  AuthException _handleFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return AuthException(
          code: e.code,
          message: 'Pogrešan email ili lozinka.',
        );
      case 'email-already-in-use':
        return AuthException(
          code: e.code,
          message: 'Nalog sa ovim email-om već postoji.',
        );
      case 'weak-password':
        return AuthException(
          code: e.code,
          message: 'Lozinka mora imati najmanje 6 karaktera.',
        );
      case 'invalid-email':
        return AuthException(
          code: e.code,
          message: 'Email adresa nije ispravna.',
        );
      case 'too-many-requests':
        return AuthException(
          code: e.code,
          message: 'Previše pokušaja. Pokušajte ponovo za nekoliko minuta.',
        );
      case 'network-request-failed':
        return AuthException(
          code: e.code,
          message: 'Nema internet konekcije.',
        );
      default:
        return AuthException(
          code: e.code,
          message: 'Greška: ${e.message}',
        );
    }
  }
}

class AuthException implements Exception {
  final String code;
  final String message;

  AuthException({required this.code, required this.message});

  @override
  String toString() => message;
}