import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';

// ─── Hive Adapter za cached shift ─────────────────────────────────────────────
// Čuvamo sirove podatke kao Map da izbegnemo kompleksne adaptere

class OfflineCacheService {
  static const String _shiftsBoxName = 'cached_shifts';
  static const String _userBoxName = 'cached_user';
  static const String _companyBoxName = 'cached_company';

  static Box<dynamic>? _shiftsBox;
  static Box<dynamic>? _userBox;
  static Box<dynamic>? _companyBox;

  // ─── INIT ───────────────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    await Hive.initFlutter();
    _shiftsBox = await Hive.openBox<dynamic>(_shiftsBoxName);
    _userBox = await Hive.openBox<dynamic>(_userBoxName);
    _companyBox = await Hive.openBox<dynamic>(_companyBoxName);
    debugPrint('Hive offline cache inicijalizovan');
  }

  // ─── SHIFTS CACHE ─────────────────────────────────────────────────────────────

  /// Čuva smene za određeni dan (ključ: "workerId_YYYY-MM-DD")
  static Future<void> cacheShiftsForDay({
    required String workerId,
    required DateTime date,
    required List<Map<String, dynamic>> shifts,
  }) async {
    final key = _shiftKey(workerId, date);
    await _shiftsBox?.put(key, {
      'shifts': shifts,
      'cached_at': DateTime.now().toIso8601String(),
    });
  }

  /// Učitava smene iz cache-a za određeni dan
  static List<Map<String, dynamic>>? getCachedShiftsForDay({
    required String workerId,
    required DateTime date,
  }) {
    final key = _shiftKey(workerId, date);
    final data = _shiftsBox?.get(key);
    if (data == null) return null;

    final cachedAt = DateTime.parse(data['cached_at'] as String);
    // Cache važi 24h
    if (DateTime.now().difference(cachedAt).inHours > 24) {
      _shiftsBox?.delete(key);
      return null;
    }

    final rawList = data['shifts'] as List;
    return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Čuva smene za sedmicu
  static Future<void> cacheShiftsForWeek({
    required String workerId,
    required DateTime weekStart,
    required List<Map<String, dynamic>> shifts,
  }) async {
    final key = _weekKey(workerId, weekStart);
    await _shiftsBox?.put(key, {
      'shifts': shifts,
      'cached_at': DateTime.now().toIso8601String(),
    });
  }

  static List<Map<String, dynamic>>? getCachedShiftsForWeek({
    required String workerId,
    required DateTime weekStart,
  }) {
    final key = _weekKey(workerId, weekStart);
    final data = _shiftsBox?.get(key);
    if (data == null) return null;

    final cachedAt = DateTime.parse(data['cached_at'] as String);
    if (DateTime.now().difference(cachedAt).inHours > 24) {
      _shiftsBox?.delete(key);
      return null;
    }

    final rawList = data['shifts'] as List;
    return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ─── USER CACHE ───────────────────────────────────────────────────────────────

  static Future<void> cacheUser(Map<String, dynamic> userData) async {
    await _userBox?.put('current_user', userData);
  }

  static Map<String, dynamic>? getCachedUser() {
    final data = _userBox?.get('current_user');
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  // ─── COMPANY CACHE ────────────────────────────────────────────────────────────

  static Future<void> cacheCompany(Map<String, dynamic> companyData) async {
    await _companyBox?.put('current_company', companyData);
  }

  static Map<String, dynamic>? getCachedCompany() {
    final data = _companyBox?.get('current_company');
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  // ─── CLEAR ────────────────────────────────────────────────────────────────────

  static Future<void> clearAll() async {
    await _shiftsBox?.clear();
    await _userBox?.clear();
    await _companyBox?.clear();
  }

  static Future<void> clearShifts() async {
    await _shiftsBox?.clear();
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────────

  static String _shiftKey(String workerId, DateTime date) {
    return '${workerId}_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _weekKey(String workerId, DateTime weekStart) {
    return 'week_${workerId}_${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
  }
}
