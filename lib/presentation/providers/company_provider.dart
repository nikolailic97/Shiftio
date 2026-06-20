import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shiftio/data/models/company_model.dart';
import 'package:shiftio/data/models/user_model.dart';
import 'package:shiftio/data/services/firestore_service.dart';

class CompanyProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();

  CompanyModel? _company;
  List<UserModel> _team = [];
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<CompanyModel?>? _companySub;
  StreamSubscription<List<UserModel>>? _teamSub;

  CompanyModel? get company => _company;
  List<UserModel> get team => _team;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get companyName => _company?.name ?? 'Shiftio';

  void init(String companyId) {
    _isLoading = true;
    notifyListeners();

    _companySub = _service.watchCompany(companyId).listen((company) {
      _company = company;
      _isLoading = false;
      notifyListeners();
    });

    _teamSub = _service.watchTeamMembers(companyId).listen((team) {
      _team = team;
      notifyListeners();
    });
  }

  /// Dodeli manager ulogu
  Future<bool> assignManagerRole(String uid) async {
    try {
      await _service.setUserRole(uid, UserRole.manager);
      return true;
    } catch (e) {
      _errorMessage = 'Greška pri dodeli uloge';
      notifyListeners();
      return false;
    }
  }

  /// Ukloni manager ulogu
  Future<bool> revokeManagerRole(String uid) async {
    try {
      await _service.setUserRole(uid, UserRole.worker);
      return true;
    } catch (e) {
      _errorMessage = 'Greška pri uklanjanju uloge';
      notifyListeners();
      return false;
    }
  }

  /// Ukloni radnika iz firme
  Future<bool> removeWorker(String uid) async {
    try {
      await _service.removeWorker(uid);
      return true;
    } catch (e) {
      _errorMessage = 'Greška pri uklanjanju radnika';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _companySub?.cancel();
    _teamSub?.cancel();
    super.dispose();
  }
}
