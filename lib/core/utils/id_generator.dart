import 'dart:math';

class IdGenerator {
  IdGenerator._();

  static const String _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final Random _random = Random.secure();

  /// Generiše 15-karakterni company ID u formatu: SHFT-XXX-XXX-XXX
  /// Primer: SHFT-829-X12-B9K
  static String generateCompanyId() {
    final part1 = _randomSegment(3);
    final part2 = _randomSegment(3);
    final part3 = _randomSegment(3);
    return 'SHFT-$part1-$part2-$part3';
  }

  static String _randomSegment(int length) {
    return List.generate(
      length,
      (_) => _chars[_random.nextInt(_chars.length)],
    ).join();
  }

  /// Validira format company ID-a
  static bool isValidCompanyId(String id) {
    final regex = RegExp(
      r'^SHFT-[A-Z0-9]{3}-[A-Z0-9]{3}-[A-Z0-9]{3}$',
    );
    return regex.hasMatch(id.toUpperCase().trim());
  }

  /// Formatira unos korisnika u toku kucanja
  /// "SHFT829X12B9K" → "SHFT-829-X12-B9K"
  static String formatInput(String raw) {
    final clean = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean.isEmpty) return '';

    final buffer = StringBuffer();
    for (int i = 0; i < clean.length && i < 15; i++) {
      if (i == 4 || i == 7 || i == 10) buffer.write('-');
      // Preskoči 'SHFT' prefix ako ga korisnik kuca ručno
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }
}
