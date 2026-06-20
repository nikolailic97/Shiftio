import 'package:flutter/material.dart';
import 'package:shiftio/data/models/company_model.dart';
import 'package:shiftio/data/models/user_model.dart';
import 'package:shiftio/data/services/auth_service.dart';
import 'package:shiftio/data/services/revenuecat_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.initial;
  UserModel? _currentUser;
  CompanyModel? _currentCompany;
  String? _errorMessage;
  bool _rememberMe = false;
  String _savedEmail = '';

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  CompanyModel? get currentCompany => _currentCompany;
  String? get errorMessage => _errorMessage;
  bool get rememberMe => _rememberMe;
  String get savedEmail => _savedEmail;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    _status = AuthStatus.loading;
    notifyListeners();

    // Učitaj saved login data
    final savedData = await _authService.getSavedLoginData();
    _rememberMe = savedData['rememberMe'];
    _savedEmail = savedData['email'];

    // Slušaj auth state
    _authService.authStateChanges.listen((user) async {
      if (user != null) {
        final userModel = await _authService.getCurrentUserModel();
        if (userModel != null && userModel.activeStatus) {
          _currentUser = userModel;
          _status = AuthStatus.authenticated;
        } else {
          _status = AuthStatus.unauthenticated;
        }
      } else {
        _currentUser = null;
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    });
  }

  // ─── LOGIN ──────────────────────────────────────────────────────────────────
  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    _setLoading();
    try {
      _currentUser = await _authService.loginWithEmail(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );
      _rememberMe = rememberMe;
      _status = AuthStatus.authenticated;
      _errorMessage = null;

      // Inicijalizuj RevenueCat za admin korisnike
      if (_currentUser != null && _currentUser!.isAdmin) {
        await RevenueCatService().initialize(_currentUser!.uid);
      }

      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  // ─── BIOMETRIC ──────────────────────────────────────────────────────────────
  Future<bool> loginWithBiometrics() async {
    final success = await _authService.authenticateWithBiometrics();
    if (success && _savedEmail.isNotEmpty) {
      // Biometrija samo otvara pristup ako je već prijavljen
      return true;
    }
    return false;
  }

  // ─── REGISTER EMPLOYER ──────────────────────────────────────────────────────
  Future<bool> registerEmployer({
    required String name,
    required String surname,
    required String email,
    required String phone,
    required String password,
    required String companyName,
    DateTime? birthDate,
  }) async {
    _setLoading();
    try {
      _currentUser = await _authService.registerEmployer(
        name: name,
        surname: surname,
        email: email,
        phone: phone,
        password: password,
        companyName: companyName,
        birthDate: birthDate,
      );
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  // ─── VALIDATE COMPANY CODE ──────────────────────────────────────────────────
  Future<CompanyModel?> validateCompanyCode(String code) async {
    return await _authService.validateCompanyCode(code);
  }

  // ─── REGISTER WORKER ────────────────────────────────────────────────────────
  Future<bool> registerWorker({
    required String name,
    required String surname,
    required String email,
    required String phone,
    required String password,
    required String companyId,
    DateTime? birthDate,
  }) async {
    _setLoading();
    try {
      _currentUser = await _authService.registerWorker(
        name: name,
        surname: surname,
        email: email,
        phone: phone,
        password: password,
        companyId: companyId,
        birthDate: birthDate,
      );
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  // ─── LOGOUT ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    _currentCompany = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ─── RESET PASSWORD ─────────────────────────────────────────────────────────
  Future<bool> sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────────
  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = AuthStatus.unauthenticated;
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
