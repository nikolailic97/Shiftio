import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shiftio/data/models/request_model.dart';
import 'package:shiftio/data/services/request_service.dart';

class RequestProvider extends ChangeNotifier {
  final RequestService _service = RequestService();

  List<RequestModel> _requests = [];
  RequestModel? _activeSickLeave;
  int _pendingCount = 0;
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<List<RequestModel>>? _requestSub;
  StreamSubscription<int>? _pendingSub;

  List<RequestModel> get requests => _requests;
  RequestModel? get activeSickLeave => _activeSickLeave;
  int get pendingCount => _pendingCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasSickLeave => _activeSickLeave != null;

  List<RequestModel> get pendingRequests =>
      _requests.where((r) => r.isPending).toList();

  // ─── INIT ─────────────────────────────────────────────────────────────────────

  void initForAdmin(String companyId) {
    _requestSub?.cancel();
    _pendingSub?.cancel();

    _requestSub = _service.watchCompanyRequests(companyId).listen((requests) {
      _requests = requests;
      notifyListeners();
    });

    _pendingSub = _service.watchPendingCount(companyId).listen((count) {
      _pendingCount = count;
      notifyListeners();
    });
  }

  void initForWorker(String userId) async {
    _requestSub?.cancel();

    _requestSub = _service.watchWorkerRequests(userId).listen((requests) {
      _requests = requests;
      notifyListeners();
    });

    // Proveri aktivno bolovanje
    _activeSickLeave = await _service.getActiveSickLeave(userId);
    notifyListeners();
  }

  // ─── VACATION ─────────────────────────────────────────────────────────────────

  Future<bool> requestVacation({
    required String userId,
    required String companyId,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _service.createVacationRequest(
        userId: userId,
        companyId: companyId,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Greška pri slanju zahteva';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── SICK LEAVE ───────────────────────────────────────────────────────────────

  Future<bool> startSickLeave({
    required String userId,
    required String companyId,
  }) async {
    try {
      await _service.startSickLeave(userId: userId, companyId: companyId);
      _activeSickLeave = await _service.getActiveSickLeave(userId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Greška pri pokretanju bolovanja';
      notifyListeners();
      return false;
    }
  }

  Future<bool> endSickLeave() async {
    if (_activeSickLeave == null) return false;
    try {
      await _service.endSickLeave(_activeSickLeave!.requestId);
      _activeSickLeave = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Greška pri završavanju bolovanja';
      notifyListeners();
      return false;
    }
  }

  // ─── ADMIN ACTIONS ────────────────────────────────────────────────────────────

  Future<bool> approveRequest({
    required String requestId,
    required String reviewedBy,
  }) async {
    try {
      await _service.approveRequest(
          requestId: requestId, reviewedBy: reviewedBy);
      return true;
    } catch (e) {
      _errorMessage = 'Greška pri odobravanju';
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectRequest({
    required String requestId,
    required String reviewedBy,
    String? rejectNote,
  }) async {
    try {
      await _service.rejectRequest(
        requestId: requestId,
        reviewedBy: reviewedBy,
        rejectNote: rejectNote,
      );
      return true;
    } catch (e) {
      _errorMessage = 'Greška pri odbijanju';
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelRequest(String requestId) async {
    try {
      await _service.cancelRequest(requestId);
      return true;
    } catch (e) {
      _errorMessage = 'Greška pri otkazivanju';
      notifyListeners();
      return false;
    }
  }

  // ─── SUPPORT ──────────────────────────────────────────────────────────────────

  Future<bool> sendSupportTicket({
    required String userId,
    required String message,
  }) async {
    try {
      await _service.sendSupportTicket(userId: userId, message: message);
      return true;
    } catch (e) {
      _errorMessage = 'Greška pri slanju poruke';
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
    _requestSub?.cancel();
    _pendingSub?.cancel();
    super.dispose();
  }
}
