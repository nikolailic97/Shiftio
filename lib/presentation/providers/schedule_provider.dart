import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shiftio/data/models/shift_model.dart';
import 'package:shiftio/data/models/user_model.dart';
import 'package:shiftio/data/services/firestore_service.dart';
import 'package:shiftio/data/services/offline_cache_service.dart';
import 'package:shiftio/data/services/connectivity_service.dart';

class ScheduleProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final ConnectivityService _connectivity = ConnectivityService();

  DateTime _selectedDate = DateTime.now();
  List<ShiftModel> _shiftsForDay = [];
  List<ShiftModel> _shiftsForWeek = [];
  List<UserModel> _teamMembers = [];
  bool _isLoading = false;
  bool _isFromCache = false;
  String? _errorMessage;

  StreamSubscription<List<ShiftModel>>? _daySubscription;
  StreamSubscription<List<ShiftModel>>? _weekSubscription;
  StreamSubscription<List<UserModel>>? _teamSubscription;

  DateTime get selectedDate => _selectedDate;
  List<ShiftModel> get shiftsForDay => _shiftsForDay;
  List<ShiftModel> get shiftsForWeek => _shiftsForWeek;
  List<UserModel> get teamMembers => _teamMembers;
  bool get isLoading => _isLoading;
  bool get isFromCache => _isFromCache;
  String? get errorMessage => _errorMessage;

  /// Dani u trenutnom mjesecu koji imaju smene (za calendar dots)
  Set<int> get daysWithShifts => _shiftsForWeek.map((s) => s.date.day).toSet();

  // ─── INIT ────────────────────────────────────────────────────────────────────

  void initForAdmin(String companyId) {
    _cancelSubscriptions();
    _listenDayShiftsAdmin(companyId);
    _listenWeekShiftsAdmin(companyId);
    _listenTeam(companyId);
  }

  void initForWorker(String workerId, String companyId) {
    _cancelSubscriptions();
    _listenDayShiftsWorker(workerId);
    _listenWeekShiftsWorker(workerId);
    _listenTeam(companyId);
  }

  // ─── SELECT DATE ─────────────────────────────────────────────────────────────

  void selectDate(DateTime date, {String? companyId, String? workerId}) {
    final prevWeekStart = _getWeekStart(_selectedDate);
    _selectedDate = date;
    notifyListeners();

    final weekChanged = _getWeekStart(date) != prevWeekStart;

    if (companyId != null) {
      _listenDayShiftsAdmin(companyId);
      if (weekChanged) _listenWeekShiftsAdmin(companyId);
    } else if (workerId != null) {
      _listenDayShiftsWorker(workerId);
      if (weekChanged) _listenWeekShiftsWorker(workerId);
    }
  }

  // ─── ADMIN STREAMS ────────────────────────────────────────────────────────────

  void _listenDayShiftsAdmin(String companyId) {
    _daySubscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _daySubscription = _firestoreService
        .watchShiftsForDate(companyId: companyId, date: _selectedDate)
        .listen(
      (shifts) {
        _shiftsForDay = shifts;
        _isLoading = false;
        _isFromCache = false;
        notifyListeners();
      },
      onError: (_) {
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _listenWeekShiftsAdmin(String companyId) {
    _weekSubscription?.cancel();
    _weekSubscription = _firestoreService
        .watchCompanyShiftsForWeek(
      companyId: companyId,
      weekStart: _getWeekStart(_selectedDate),
    )
        .listen((shifts) {
      _shiftsForWeek = shifts;
      notifyListeners();
    });
  }

  // ─── WORKER STREAMS (sa offline cache) ───────────────────────────────────────

  void _listenDayShiftsWorker(String workerId) {
    _daySubscription?.cancel();
    _isLoading = true;
    notifyListeners();

    // Odmah prikaži cache ako smo offline
    if (!_connectivity.isOnline) {
      final cached = OfflineCacheService.getCachedShiftsForDay(
        workerId: workerId,
        date: _selectedDate,
      );
      if (cached != null) {
        _shiftsForDay =
            cached.map(_shiftFromMap).whereType<ShiftModel>().toList();
        _isLoading = false;
        _isFromCache = true;
        notifyListeners();
        return;
      }
    }

    _daySubscription = _firestoreService
        .watchWorkerShiftsForDate(workerId: workerId, date: _selectedDate)
        .listen(
      (shifts) {
        _shiftsForDay = shifts;
        _isLoading = false;
        _isFromCache = false;
        notifyListeners();

        // Keširaj za offline
        OfflineCacheService.cacheShiftsForDay(
          workerId: workerId,
          date: _selectedDate,
          shifts: shifts.map((s) => s.toFirestore()).toList(),
        );
      },
      onError: (_) {
        final cached = OfflineCacheService.getCachedShiftsForDay(
          workerId: workerId,
          date: _selectedDate,
        );
        if (cached != null) {
          _shiftsForDay =
              cached.map(_shiftFromMap).whereType<ShiftModel>().toList();
          _isFromCache = true;
        }
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _listenWeekShiftsWorker(String workerId) {
    _weekSubscription?.cancel();

    if (!_connectivity.isOnline) {
      final cached = OfflineCacheService.getCachedShiftsForWeek(
        workerId: workerId,
        weekStart: _getWeekStart(_selectedDate),
      );
      if (cached != null) {
        _shiftsForWeek =
            cached.map(_shiftFromMap).whereType<ShiftModel>().toList();
        notifyListeners();
        return;
      }
    }

    _weekSubscription = _firestoreService
        .watchWorkerShiftsForWeek(
      workerId: workerId,
      weekStart: _getWeekStart(_selectedDate),
    )
        .listen((shifts) {
      _shiftsForWeek = shifts;
      notifyListeners();

      OfflineCacheService.cacheShiftsForWeek(
        workerId: workerId,
        weekStart: _getWeekStart(_selectedDate),
        shifts: shifts.map((s) => s.toFirestore()).toList(),
      );
    });
  }

  void _listenTeam(String companyId) {
    _teamSubscription?.cancel();
    _teamSubscription =
        _firestoreService.watchTeamMembers(companyId).listen((members) {
      _teamMembers = members;
      notifyListeners();
    });
  }

  // ─── CREATE / DELETE / COMMENT ────────────────────────────────────────────────

  Future<bool> createShift({
    required String companyId,
    required List<String> workerIds,
    required DateTime startTime,
    required int durationMinutes,
    required DateTime date,
    String? noteAdmin,
    bool sendNotification = false,
  }) async {
    try {
      await _firestoreService.createShiftsBatch(
        companyId: companyId,
        workerIds: workerIds,
        startTime: startTime,
        durationMinutes: durationMinutes,
        date: date,
        noteAdmin: noteAdmin,
        sendNotification: sendNotification,
      );
      return true;
    } catch (e) {
      _errorMessage = 'Greška pri kreiranju smene';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteShift(String shiftId) async {
    try {
      await _firestoreService.deleteShift(shiftId);
      return true;
    } catch (e) {
      _errorMessage = 'Greška pri brisanju smene';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteShiftsBatch(String batchId) async {
    try {
      await _firestoreService.deleteShiftsBatch(batchId);
      return true;
    } catch (e) {
      _errorMessage = 'Greška pri brisanju smena';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addWorkerComment(String shiftId, String comment) async {
    try {
      await _firestoreService.addWorkerComment(shiftId, comment);
      return true;
    } catch (e) {
      _errorMessage = 'Greška pri slanju komentara';
      notifyListeners();
      return false;
    }
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────────

  DateTime _getWeekStart(DateTime date) {
    return DateTime(date.year, date.month, date.day - (date.weekday - 1));
  }

  ShiftModel? _shiftFromMap(Map<String, dynamic> data) {
    try {
      return ShiftModel(
        shiftId: data['shift_id'] ?? '',
        companyId: data['company_id'] ?? '',
        workerId: data['worker_id'] ?? '',
        batchId: data['batch_id'],
        startTime: _parseDateTime(data['start_time']),
        durationMinutes: data['duration_minutes'] ?? 0,
        date: _parseDateTime(data['date']),
        noteAdmin: data['note_admin'],
        workerComment: data['worker_comment'],
        hasComment: data['has_comment'] ?? false,
        timestamp: _parseDateTime(data['timestamp']),
        notificationSent: data['notification_sent'] ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  List<ShiftModel> getShiftsForWorker(String workerId) {
    return _shiftsForDay.where((s) => s.workerId == workerId).toList();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _cancelSubscriptions() {
    _daySubscription?.cancel();
    _weekSubscription?.cancel();
    _teamSubscription?.cancel();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
