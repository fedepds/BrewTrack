double _d(Object? v) => (v as num).toDouble();

typedef LotFilter = ({String country, String process});
typedef RoastFilter = ({String lotId, String level, String from, String to});

class User {
  const User({required this.id, required this.email, required this.name, required this.role, required this.active});
  User.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        email = j['email'],
        name = j['name'],
        role = j['role'],
        active = j['active'];
  final String id, email, name, role;
  final bool active;
  bool get isAdmin => role == 'admin';
}

class Lot {
  Lot.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        code = j['code'],
        originCountry = j['origin_country'],
        region = j['region'],
        farm = j['farm'],
        producer = j['producer'],
        variety = j['variety'],
        process = j['process'],
        altitudeM = j['altitude_m'],
        harvestYear = j['harvest_year'],
        receivedAt = j['received_at'],
        receivedKg = _d(j['received_kg']),
        notes = j['notes'],
        stockKg = _d(j['stock_kg']);
  final String id, code, originCountry, variety, process, receivedAt;
  final String? region, farm, producer, notes;
  final int? altitudeM;
  final int harvestYear;
  final double receivedKg, stockKg;
}

class Roast {
  Roast.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        lotId = j['lot_id'],
        lotCode = j['lot_code'],
        roasterId = j['roaster_id'],
        roasterName = j['roaster_name'],
        roastedAt = DateTime.parse(j['roasted_at']),
        greenInKg = _d(j['green_in_kg']),
        roastedOutKg = _d(j['roasted_out_kg']),
        lossPct = _d(j['loss_pct']),
        durationS = j['duration_s'],
        dropTempC = _d(j['drop_temp_c']),
        roastLevel = j['roast_level'],
        notes = j['notes'];
  final String id, lotId, lotCode, roasterId, roasterName, roastLevel;
  final DateTime roastedAt;
  final double greenInKg, roastedOutKg, lossPct, dropTempC;
  final int durationS;
  final String? notes;
}

class LotDetail {
  LotDetail.fromJson(Map<String, dynamic> j)
      : lot = Lot.fromJson(j),
        roasts = [for (final r in j['roasts']) Roast.fromJson(r as Map<String, dynamic>)];
  final Lot lot;
  final List<Roast> roasts;
}

class RoastDetail {
  RoastDetail.fromJson(Map<String, dynamic> j)
      : roast = Roast.fromJson(j),
        lot = Lot.fromJson(j['lot'] as Map<String, dynamic>);
  final Roast roast;
  final Lot lot;
}

class Paged<T> {
  const Paged(this.items, this.total);
  final List<T> items;
  final int total;
}

Paged<T> pageFrom<T>(Map<String, dynamic> j, T Function(Map<String, dynamic>) f) =>
    Paged([for (final i in j['items']) f(i as Map<String, dynamic>)], j['total']);

const roastLevels = {'light': 'Claro', 'medium': 'Medio', 'dark': 'Oscuro'};

class Summary {
  Summary.fromJson(Map<String, dynamic> j)
      : month = j['month'],
        lotsInStock = j['lots_in_stock'],
        stockKg = j['stock_kg'],
        receivedLots = j['received']['lots'],
        receivedKg = j['received']['kg'],
        roasts = j['roasted']['roasts'],
        greenKg = j['roasted']['green_kg'],
        roastedKg = j['roasted']['roasted_kg'],
        lossPct = j['loss_pct'];
  // Los kg y la merma llegan como texto ya formateado por la API.
  final String month, stockKg, receivedKg, greenKg, roastedKg;
  final int lotsInStock, receivedLots, roasts;
  final String? lossPct;
}
