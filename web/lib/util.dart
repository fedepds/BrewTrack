import 'models.dart';

/// Merma en %, o null si los pesos están vacíos o son incoherentes.
double? lossPct(double? inKg, double? outKg) {
  if (inKg == null || outKg == null || inKg <= 0 || outKg < 0 || outKg > inKg) return null;
  return (inKg - outKg) / inKg * 100;
}

bool canEditRoast(User u, Roast r) => u.isAdmin || r.roasterId == u.id;

String fmtKg(double v) => '${v.toStringAsFixed(3)} kg';

/// 'AAAA-MM-DD HH:mm' en hora local.
String fmtDate(DateTime d) => d.toLocal().toIso8601String().substring(0, 16).replaceFirst('T', ' ');

const _months = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// 'AAAA-MM' → 'octubre 2026'.
String monthLabel(String ym) => '${_months[int.parse(ym.substring(5)) - 1]} ${ym.substring(0, 4)}';

/// Suma [delta] meses a 'AAAA-MM'.
String shiftMonth(String ym, int delta) {
  final d = DateTime(int.parse(ym.substring(0, 4)), int.parse(ym.substring(5)) + delta);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}';
}
