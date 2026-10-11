import 'package:brewtrack_web/models.dart';
import 'package:brewtrack_web/util.dart';
import 'package:flutter_test/flutter_test.dart';

Roast _roast(String roasterId) => Roast.fromJson({
      'id': 'r1', 'lot_id': 'l1', 'lot_code': 'GL-1', 'roaster_id': roasterId, 'roaster_name': 'Ana',
      'roasted_at': '2026-02-01T10:00:00Z', 'green_in_kg': 10, 'roasted_out_kg': 8.5, 'loss_pct': 15.0,
      'duration_s': 600, 'drop_temp_c': 205.0, 'roast_level': 'medium', 'notes': null,
    });

User _user(String id, String role) =>
    User(id: id, email: '$id@x.com', name: id, role: role, active: true);

void main() {
  test('lossPct calcula la merma', () {
    expect(lossPct(10, 8.5), closeTo(15, 1e-9));
    expect(lossPct(10, 10), 0);
  });

  test('lossPct devuelve null con pesos vacíos, cero o incoherentes', () {
    expect(lossPct(null, 5), isNull);
    expect(lossPct(10, null), isNull);
    expect(lossPct(0, 0), isNull);
    expect(lossPct(10, 11), isNull);
  });

  test('canEditRoast: autor o admin', () {
    final r = _roast('ana');
    expect(canEditRoast(_user('ana', 'roaster'), r), isTrue);
    expect(canEditRoast(_user('bob', 'roaster'), r), isFalse);
    expect(canEditRoast(_user('bob', 'admin'), r), isTrue);
  });

  test('monthLabel muestra el mes en español', () {
    expect(monthLabel('2026-10'), 'octubre 2026');
    expect(monthLabel('2027-01'), 'enero 2027');
  });

  test('shiftMonth cruza el cambio de año', () {
    expect(shiftMonth('2026-10', -1), '2026-09');
    expect(shiftMonth('2026-01', -1), '2025-12');
    expect(shiftMonth('2026-12', 1), '2027-01');
  });
}
