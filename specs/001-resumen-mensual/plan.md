# Resumen mensual: plan de implementación

> **Para agentes:** SUB-SKILL REQUERIDA: usa superpowers:subagent-driven-development (recomendada) o superpowers:executing-plans para implementar este plan tarea por tarea. Los pasos usan casillas (`- [ ]`) para seguir el avance.

**Objetivo:** una pantalla "Resumen" con cinco cifras (stock de hoy, recibido, tostado y merma del mes), servida por `GET /api/v1/stats/summary`.

**Arquitectura:** un router nuevo de FastAPI hace tres consultas de agregación (stock, recibido y tostado) y devuelve los kg como texto con decimales fijos. El mes se mide en la zona horaria del taller (`TIMEZONE`). En Flutter, una pantalla nueva pide el resumen sin `month` la primera vez y toma de la respuesta el mes actual del taller. Las flechas cambian de mes desde ahí.

**Stack:** FastAPI, SQLAlchemy 2, `zoneinfo` (stdlib), pytest; Flutter, Riverpod 2, go_router, dio.

**Spec:** `specs/001-resumen-mensual/spec.md` (aprobada, v1.1).

## Restricciones globales

- El stock no se guarda: es `received_kg` menos la suma de `green_in_kg`, y se calcula con `used_expr()` de `api/app/stock.py`.
- Todo error usa `{"error": {"code", "message"}}`. Ya lo hace `api/app/errors.py` para 401 y 422.
- Endpoint bajo `/api/v1`, para los roles `roaster` y `admin`.
- Formato de la respuesta (RF-16): los kg van como texto con 3 decimales y `loss_pct` como texto con 2 decimales o `null`. **Ojo:** el resto de la API manda los Decimal como número JSON (`Num` en `schemas.py`). Aquí la spec manda texto, y esta pantalla no usa `Num`.
- La merma se redondea con la mitad hacia arriba (`ROUND_HALF_UP`) y se calcula sobre los totales, no como el promedio de cada tueste.
- `TIMEZONE` vale `America/Argentina/Buenos_Aires` por defecto. El mes va del día 1 a las 00:00 al día 1 del mes siguiente, sin incluirlo, en esa zona.
- El esquema no cambia, así que no hay migración.
- Los textos de la interfaz van en español. No se tocan `.env`, `.venv/`, `.pubcache/`, `.superpowers/` ni `web/build/`.
- Commits en Conventional Commits con alcance: `feat(api): ...`, `feat(web): ...`.

## Puntos para revisar

Casos que la spec no prueba de forma explícita pero que pueden fallarle a alguien. Cada uno tiene su prueba en la tarea indicada.

1. **`TIMEZONE` mal escrita** (`Marte/Olympus`): la API no debe arrancar, en vez de responder 500 en cada pedido. Hay un validador en `Settings` (Tarea 1).
2. **Años fuera de rango** (`0000-01`, `9999-12`): `date()` fallaría y daría 500. El patrón de `month` acepta solo años 1900–2099 y devuelve 422 (Tarea 1).
3. **Cambio de año:** un tueste del 31-12 a las 23:00 cuenta en diciembre y no en enero. Desde enero, la flecha "anterior" lleva a diciembre del año anterior (Tareas 1 y 2).
4. **Redondeo justo a la mitad:** una merma de 12.345 da `"12.35"`, no `"12.34"` como daría un float (Tarea 1).
5. **Error de la API en pantalla:** se muestra el mensaje del backend y las flechas quedan desactivadas, sin romper la pantalla (Tarea 2).

---

## Archivos

| Archivo | Cambio | Responsabilidad |
|---|---|---|
| `api/app/config.py` | Modificar | `timezone` con valor por defecto y validador |
| `api/app/routers/stats.py` | Crear | `GET /stats/summary` y sus modelos de respuesta |
| `api/app/main.py` | Modificar | Registrar el router |
| `api/tests/test_stats.py` | Crear | CA-1 a CA-17 y puntos 1 a 4 |
| `.env.example`, `compose.yaml` | Modificar | Documentar y pasar `TIMEZONE` |
| `web/lib/models.dart` | Modificar | Clase `Summary` |
| `web/lib/api.dart` | Modificar | `Api.summary(String? month)` |
| `web/lib/providers.dart` | Modificar | `summaryProvider` |
| `web/lib/util.dart` | Modificar | `monthLabel`, `shiftMonth` |
| `web/lib/stats_screen.dart` | Crear | Pantalla "Resumen" |
| `web/test/util_test.dart` | Modificar | Pruebas de `monthLabel` y `shiftMonth` |
| `web/test/stats_screen_test.dart` | Crear | CA-18 a CA-23 y punto 5 |
| `web/lib/router.dart`, `web/lib/shell.dart` | Modificar | Ruta `/stats` y destino "Resumen" |
| `web/test/shell_test.dart` | Modificar | CA-24 y CA-25 |

---

### Tarea 1: API: endpoint `/stats/summary`

**Archivos:**
- Modificar: `api/app/config.py`
- Crear: `api/app/routers/stats.py`
- Modificar: `api/app/main.py`
- Modificar: `.env.example`, `compose.yaml` (servicio `api`, bloque `environment`)
- Crear: `api/tests/test_stats.py`

**Interfaces:**
- Consume: `used_expr()` de `app.stock`, `current_user` de `app.deps`, `get_db` de `app.db`, y los fixtures de `tests/conftest.py` (`client`, `auth`, `roaster`, `admin`, `make_user`, `make_lot`, `make_roast`).
- Produce: `GET /api/v1/stats/summary?month=YYYY-MM`, que devuelve
  `{"month": str, "lots_in_stock": int, "stock_kg": str, "received": {"lots": int, "kg": str}, "roasted": {"roasts": int, "green_kg": str, "roasted_kg": str}, "loss_pct": str | null}`.
  También `settings.timezone: str`.

**Requisito previo:** el Postgres de pruebas en `localhost:55432`. Ver `docs/superpowers/plans/2026-10-07-brewtrack.md`, Task 2.

- [ ] **Paso 1: escribir las pruebas que fallan**

`api/tests/test_stats.py`:

```python
from datetime import date, datetime
from zoneinfo import ZoneInfo

import pytest
from pydantic import ValidationError

from app.config import Settings, settings

URL = "/api/v1/stats/summary"
BA = ZoneInfo("America/Argentina/Buenos_Aires")
ZERO_RECEIVED = {"lots": 0, "kg": "0.000"}
ZERO_ROASTED = {"roasts": 0, "green_kg": "0.000", "roasted_kg": "0.000"}


@pytest.fixture(autouse=True)
def _ba(monkeypatch):
    monkeypatch.setattr(settings, "timezone", "America/Argentina/Buenos_Aires")


def _get(client, auth, user, month=None):
    r = client.get(URL, params={"month": month} if month else None, headers=auth(user))
    assert r.status_code == 200, r.text
    return r.json()


def test_requires_auth(client):
    r = client.get(URL)
    assert r.status_code == 401 and set(r.json()["error"]) == {"code", "message"}


@pytest.mark.parametrize("role", ["roaster", "admin"])
def test_both_roles(client, make_user, auth, role):
    body = _get(client, auth, make_user(f"{role}@x.com", role))
    assert set(body) == {"month", "lots_in_stock", "stock_kg", "received", "roasted", "loss_pct"}


@pytest.mark.parametrize("month", ["2026-13", "octubre", "2026-1", "2026-00", "0000-01", "9999-12"])
def test_bad_month_is_422(client, roaster, auth, month):
    r = client.get(URL, params={"month": month}, headers=auth(roaster))
    assert r.status_code == 422 and r.json()["error"]["code"] == "validation_error"


def test_received_counts_only_the_month(client, roaster, auth, make_lot):
    make_lot("GL-1", kg="50", received_at=date(2026, 9, 30))
    make_lot("GL-2", kg="60", received_at=date(2026, 10, 1))
    make_lot("GL-3", kg="60", received_at=date(2026, 10, 31))
    assert _get(client, auth, roaster, "2026-10")["received"] == {"lots": 2, "kg": "120.000"}


def test_roasted_counts_only_the_month(client, roaster, auth, make_lot, make_roast):
    lot = make_lot(kg="100")
    mid_oct = datetime(2026, 10, 15, 12, tzinfo=BA)
    make_roast(lot, roaster, "10", "8.5", roasted_at=mid_oct)
    make_roast(lot, roaster, "5", "4", roasted_at=mid_oct)
    make_roast(lot, roaster, "20", "17", roasted_at=datetime(2026, 9, 15, 12, tzinfo=BA))
    body = _get(client, auth, roaster, "2026-10")
    assert body["roasted"] == {"roasts": 2, "green_kg": "15.000", "roasted_kg": "12.500"}


def test_loss_is_weighted_not_averaged(client, roaster, auth, make_lot, make_roast):
    lot = make_lot(kg="100")
    at = datetime(2026, 10, 15, 12, tzinfo=BA)
    make_roast(lot, roaster, "1", "0.5", roasted_at=at)  # merma 50 %
    make_roast(lot, roaster, "19", "17.1", roasted_at=at)  # merma 10 %
    assert _get(client, auth, roaster, "2026-10")["loss_pct"] == "12.00"  # el promedio sería 30.00


def test_loss_rounds_half_up(client, roaster, auth, make_lot, make_roast):
    lot = make_lot(kg="100")
    make_roast(lot, roaster, "20", "17.531", roasted_at=datetime(2026, 10, 15, 12, tzinfo=BA))  # 12.345 %
    assert _get(client, auth, roaster, "2026-10")["loss_pct"] == "12.35"


def test_stock_today_matches_lot_listing(client, roaster, auth, make_lot, make_roast):
    used_up, partial = make_lot("GL-1", kg="30"), make_lot("GL-2", kg="20")
    make_lot("GL-3", kg="7.25")  # sin tuestes
    make_roast(used_up, roaster, "20", "17")
    make_roast(used_up, roaster, "10", "8.5")
    make_roast(partial, roaster, "5", "4")
    body = _get(client, auth, roaster, "2020-01")  # el stock no depende del mes
    assert body["lots_in_stock"] == 2 and body["stock_kg"] == "22.250"
    lots = client.get("/api/v1/green-lots", headers=auth(roaster)).json()["items"]
    assert float(body["stock_kg"]) == pytest.approx(sum(lot["stock_kg"] for lot in lots))


def test_future_dated_lot_counts_in_stock_today(client, roaster, auth, make_lot):
    make_lot(kg="10", received_at=date(2099, 1, 1))
    body = _get(client, auth, roaster)
    assert body["lots_in_stock"] == 1 and body["stock_kg"] == "10.000"


def test_month_edges_use_workshop_timezone(client, roaster, auth, make_lot, make_roast):
    lot = make_lot(kg="100")
    make_roast(lot, roaster, roasted_at=datetime(2026, 10, 31, 22, tzinfo=BA))  # 01-11 01:00 UTC
    make_roast(lot, roaster, roasted_at=datetime(2026, 10, 1, 0, tzinfo=BA))
    assert _get(client, auth, roaster, "2026-10")["roasted"]["roasts"] == 2
    assert _get(client, auth, roaster, "2026-11")["roasted"]["roasts"] == 0
    assert _get(client, auth, roaster, "2026-09")["roasted"]["roasts"] == 0


def test_year_rollover(client, roaster, auth, make_lot, make_roast):
    lot = make_lot(kg="100")
    make_roast(lot, roaster, roasted_at=datetime(2026, 12, 31, 23, tzinfo=BA))
    assert _get(client, auth, roaster, "2026-12")["roasted"]["roasts"] == 1
    assert _get(client, auth, roaster, "2027-01")["roasted"]["roasts"] == 0


@pytest.mark.parametrize("month", ["2020-01", "2099-01"])
def test_empty_month_returns_zeros(client, roaster, auth, month):
    body = _get(client, auth, roaster, month)
    assert body["month"] == month
    assert body["received"] == ZERO_RECEIVED and body["roasted"] == ZERO_ROASTED
    assert body["loss_pct"] is None and body["stock_kg"] == "0.000"


def test_default_month_is_current_in_workshop_timezone(client, roaster, auth):
    assert _get(client, auth, roaster)["month"] == datetime.now(BA).strftime("%Y-%m")


def test_timezone_default_and_validation(monkeypatch):
    monkeypatch.delenv("TIMEZONE", raising=False)
    assert Settings().timezone == "America/Argentina/Buenos_Aires"
    monkeypatch.setenv("TIMEZONE", "Marte/Olympus")
    with pytest.raises(ValidationError):
        Settings()
```

- [ ] **Paso 2: comprobar que fallan**

Ejecuta: `cd api && pytest tests/test_stats.py -v`
Esperado: FAIL. `ImportError` porque `Settings` no tiene `timezone`, o 404 en las rutas.

- [ ] **Paso 3: configuración**

`api/app/config.py`: agrega los imports y el campo con su validador.

```python
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import field_validator
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str
    jwt_secret: str
    access_ttl_min: int = 60
    refresh_ttl_days: int = 7
    # Solo importa en desarrollo (flutter run); en producción nginx hace proxy same-origin.
    cors_origins: list[str] = ["http://localhost:5000"]
    # Zona del taller: define dónde empieza y termina cada mes en el resumen.
    timezone: str = "America/Argentina/Buenos_Aires"

    @field_validator("timezone")
    @classmethod
    def _known_zone(cls, v: str) -> str:
        try:
            ZoneInfo(v)
        except (ZoneInfoNotFoundError, ValueError):
            raise ValueError(f"zona horaria desconocida: {v}")
        return v


settings = Settings()
```

`.env.example`: agrega al final:

```
# Zona horaria del taller (opcional). Define dónde empieza cada mes en el resumen.
TIMEZONE=America/Argentina/Buenos_Aires
```

`compose.yaml`: en `services.api.environment`, debajo de `JWT_SECRET`:

```yaml
      TIMEZONE: ${TIMEZONE:-America/Argentina/Buenos_Aires}
```

- [ ] **Paso 4: el router**

`api/app/routers/stats.py`:

```python
from datetime import date, datetime, time
from decimal import ROUND_HALF_UP, Decimal
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.config import settings
from app.db import get_db
from app.deps import current_user
from app.models import GreenLot, Roast
from app.stock import used_expr

router = APIRouter(prefix="/stats", tags=["stats"], dependencies=[Depends(current_user)])

# Años 1900–2099: evita que date() falle con 0000 o 9999-12.
MONTH = r"^(19|20)\d{2}-(0[1-9]|1[0-2])$"


class Received(BaseModel):
    lots: int
    kg: str


class Roasted(BaseModel):
    roasts: int
    green_kg: str
    roasted_kg: str


class Summary(BaseModel):
    month: str
    lots_in_stock: int
    stock_kg: str
    received: Received
    roasted: Roasted
    loss_pct: str | None


def _kg(v: Decimal) -> str:
    return str(Decimal(v).quantize(Decimal("0.001")))


@router.get("/summary", response_model=Summary)
def summary(month: str | None = Query(None, pattern=MONTH), db: Session = Depends(get_db)) -> Summary:
    tz = ZoneInfo(settings.timezone)
    month = month or datetime.now(tz).strftime("%Y-%m")
    y, m = map(int, month.split("-"))
    start, end = date(y, m, 1), date(y + m // 12, m % 12 + 1, 1)
    start_at, end_at = datetime.combine(start, time(), tz), datetime.combine(end, time(), tz)

    stock = GreenLot.received_kg - used_expr()
    lots_in_stock, stock_kg = db.execute(
        select(func.count().filter(stock > 0), func.coalesce(func.sum(stock), 0)).select_from(GreenLot)
    ).one()
    lots, received_kg = db.execute(
        select(func.count(), func.coalesce(func.sum(GreenLot.received_kg), 0))
        .where(GreenLot.received_at >= start, GreenLot.received_at < end)
    ).one()
    roasts, green_kg, roasted_kg = db.execute(
        select(
            func.count(),
            func.coalesce(func.sum(Roast.green_in_kg), 0),
            func.coalesce(func.sum(Roast.roasted_out_kg), 0),
        ).where(Roast.roasted_at >= start_at, Roast.roasted_at < end_at)
    ).one()

    loss = None
    if roasts:
        loss = str(((1 - roasted_kg / green_kg) * 100).quantize(Decimal("0.01"), ROUND_HALF_UP))
    return Summary(
        month=month,
        lots_in_stock=lots_in_stock,
        stock_kg=_kg(stock_kg),
        received=Received(lots=lots, kg=_kg(received_kg)),
        roasted=Roasted(roasts=roasts, green_kg=_kg(green_kg), roasted_kg=_kg(roasted_kg)),
        loss_pct=loss,
    )
```

`api/app/main.py`: agrega `stats` al import y registra el router:

```python
from app.routers import auth, green_lots, roasts, stats, users
...
app.include_router(roasts.router, prefix="/api/v1")
app.include_router(stats.router, prefix="/api/v1")
```

- [ ] **Paso 5: comprobar que pasan**

Ejecuta: `cd api && pytest tests/test_stats.py -v`, y después `cd api && pytest`.
Esperado: todo PASS, también las pruebas anteriores.

- [ ] **Paso 6: commit**

```bash
git add api/app/config.py api/app/routers/stats.py api/app/main.py api/tests/test_stats.py .env.example compose.yaml
git commit -m "feat(api): monthly summary endpoint"
```

---

### Tarea 2: web: pantalla "Resumen"

**Archivos:**
- Modificar: `web/lib/models.dart`, `web/lib/api.dart`, `web/lib/providers.dart`, `web/lib/util.dart`
- Crear: `web/lib/stats_screen.dart`
- Modificar: `web/test/util_test.dart`
- Crear: `web/test/stats_screen_test.dart`

**Interfaces:**
- Consume: el JSON de la Tarea 1, y también `asyncBody` y `apiMessage` (vía `widgets.dart`) y `apiProvider`.
- Produce:
  - `class Summary` con `String month, stockKg, receivedKg, greenKg, roastedKg; int lotsInStock, receivedLots, roasts; String? lossPct`
  - `Future<Summary> Api.summary(String? month)`
  - `summaryProvider: AutoDisposeFutureProviderFamily<Summary, String?>`, donde `null` significa el mes actual del taller
  - `String monthLabel(String ym)` y `String shiftMonth(String ym, int delta)`
  - `class StatsScreen extends ConsumerStatefulWidget` (const, sin parámetros)

- [ ] **Paso 1: escribir las pruebas de utilidades que fallan**

`web/test/util_test.dart`: agrega dentro de `main()`:

```dart
  test('monthLabel muestra el mes en español', () {
    expect(monthLabel('2026-10'), 'octubre 2026');
    expect(monthLabel('2027-01'), 'enero 2027');
  });

  test('shiftMonth cruza el cambio de año', () {
    expect(shiftMonth('2026-10', -1), '2026-09');
    expect(shiftMonth('2026-01', -1), '2025-12');
    expect(shiftMonth('2026-12', 1), '2027-01');
  });
```

- [ ] **Paso 2: escribir las pruebas de pantalla que fallan**

`web/test/stats_screen_test.dart`:

```dart
import 'package:brewtrack_web/models.dart';
import 'package:brewtrack_web/providers.dart';
import 'package:brewtrack_web/stats_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Summary _summary(String month, String? loss) => Summary.fromJson({
      'month': month, 'lots_in_stock': 7, 'stock_kg': '412.500',
      'received': {'lots': 2, 'kg': '120.000'},
      'roasted': {'roasts': 18, 'green_kg': '95.000', 'roasted_kg': '80.750'},
      'loss_pct': loss,
    });

/// Mes actual del taller fijo en 2026-10. Devuelve los meses pedidos a la API.
Future<List<String?>> pump(WidgetTester t, {String? loss = '15.00', Object? error}) async {
  final asked = <String?>[];
  await t.pumpWidget(ProviderScope(
    overrides: [
      summaryProvider.overrideWith((ref, month) async {
        asked.add(month);
        if (error != null) throw error;
        return _summary(month ?? '2026-10', loss);
      }),
    ],
    child: const MaterialApp(home: Scaffold(body: StatsScreen())),
  ));
  await t.pumpAndSettle();
  return asked;
}

VoidCallback? _onPressed(WidgetTester t, IconData icon) =>
    t.widget<IconButton>(find.widgetWithIcon(IconButton, icon)).onPressed;

void main() {
  testWidgets('muestra las cinco cifras con formato', (t) async {
    await pump(t);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('412.500 kg'), findsOneWidget);
    expect(find.text('120.000 kg'), findsOneWidget);
    expect(find.text('2 lotes'), findsOneWidget);
    expect(find.text('95.000 kg → 80.750 kg'), findsOneWidget);
    expect(find.text('18 tuestes'), findsOneWidget);
    expect(find.text('15.00 %'), findsOneWidget);
    expect(find.textContaining('hoy'), findsNWidgets(2));
  });

  testWidgets('merma nula se muestra como guion', (t) async {
    await pump(t, loss: null);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('las flechas cambian de mes; siguiente se desactiva en el mes actual', (t) async {
    final asked = await pump(t);
    expect(find.text('octubre 2026'), findsOneWidget);
    expect(_onPressed(t, Icons.chevron_right), isNull);

    await t.tap(find.byIcon(Icons.chevron_left));
    await t.pumpAndSettle();
    expect(find.text('septiembre 2026'), findsOneWidget);
    expect(asked, contains('2026-09'));
    expect(_onPressed(t, Icons.chevron_right), isNotNull);

    await t.tap(find.byIcon(Icons.chevron_right));
    await t.pumpAndSettle();
    expect(find.text('octubre 2026'), findsOneWidget);
    expect(_onPressed(t, Icons.chevron_right), isNull);
  });

  testWidgets('un error de la API muestra el mensaje del backend', (t) async {
    final ro = RequestOptions();
    await pump(t, error: DioException(requestOptions: ro, response: Response(
      requestOptions: ro, statusCode: 422,
      data: {'error': {'code': 'validation_error', 'message': 'month: formato inválido'}},
    )));
    expect(find.text('month: formato inválido'), findsOneWidget);
    expect(_onPressed(t, Icons.chevron_left), isNull);
  });
}
```

- [ ] **Paso 3: comprobar que fallan**

Ejecuta: `cd web && flutter test test/util_test.dart test/stats_screen_test.dart`
Esperado: FAIL de compilación (`monthLabel`, `Summary` y `StatsScreen` no existen).

- [ ] **Paso 4: modelo, API y provider**

`web/lib/models.dart`: agrega al final:

```dart
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
```

`web/lib/api.dart`: agrega después de `roast(...)`:

```dart
  /// [month] 'AAAA-MM'; null pide el mes actual del taller.
  Future<Summary> summary(String? month) async =>
      Summary.fromJson(await _get('/stats/summary', {if (month != null) 'month': month}));
```

`web/lib/providers.dart`: agrega al final:

```dart
final summaryProvider = FutureProvider.autoDispose
    .family<Summary, String?>((ref, month) => ref.watch(apiProvider).summary(month));
```

- [ ] **Paso 5: utilidades**

`web/lib/util.dart`: agrega al final:

```dart
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
```

- [ ] **Paso 6: la pantalla**

`web/lib/stats_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'providers.dart';
import 'util.dart';
import 'widgets.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});
  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  String? _month; // null = mes actual del taller, lo decide la API

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(summaryProvider(null)).valueOrNull?.month;
    final month = _month ?? current;
    final summary = ref.watch(summaryProvider(_month));

    void go(int delta) => setState(() {
          final m = shiftMonth(month!, delta);
          _month = m == current ? null : m;
        });

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            tooltip: 'Mes anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: month == null ? null : () => go(-1),
          ),
          SizedBox(
            width: 180,
            child: Text(
              month == null ? '' : monthLabel(month),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Mes siguiente',
            icon: const Icon(Icons.chevron_right),
            onPressed: month == null || month == current ? null : () => go(1),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(child: SingleChildScrollView(child: asyncBody(summary, _figures))),
      ]),
    );
  }

  Widget _figures(Summary s) => Wrap(spacing: 12, runSpacing: 12, children: [
        _Figure('Lotes con stock (hoy)', '${s.lotsInStock}'),
        _Figure('Stock de verde (hoy)', '${s.stockKg} kg'),
        _Figure('Recibido en el mes', '${s.receivedKg} kg', _count(s.receivedLots, 'lote', 'lotes')),
        _Figure('Tostado en el mes', '${s.greenKg} kg → ${s.roastedKg} kg', _count(s.roasts, 'tueste', 'tuestes')),
        _Figure('Merma media', s.lossPct == null ? '—' : '${s.lossPct} %'),
      ]);
}

String _count(int n, String one, String many) => '$n ${n == 1 ? one : many}';

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, [this.detail]);
  final String label, value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: text.labelLarge),
            const SizedBox(height: 8),
            Text(value, style: text.headlineSmall),
            if (detail != null) Text(detail!, style: text.bodyMedium),
          ]),
        ),
      ),
    );
  }
}
```

- [ ] **Paso 7: comprobar que pasan**

Ejecuta: `cd web && flutter test test/util_test.dart test/stats_screen_test.dart && flutter analyze`
Esperado: todo PASS y `No issues found!`.

- [ ] **Paso 8: commit**

```bash
git add web/lib/models.dart web/lib/api.dart web/lib/providers.dart web/lib/util.dart web/lib/stats_screen.dart web/test/util_test.dart web/test/stats_screen_test.dart
git commit -m "feat(web): monthly summary screen"
```

---

### Tarea 3: web: ruta y navegación

**Archivos:**
- Modificar: `web/lib/router.dart`, `web/lib/shell.dart`
- Modificar: `web/test/shell_test.dart`

**Interfaces:**
- Consume: `StatsScreen` (Tarea 2).
- Produce: la ruta `/stats` y el destino "Resumen" en `Shell`, entre "Tuestes" y "Usuarios".

- [ ] **Paso 1: escribir la prueba que falla**

`web/test/shell_test.dart`: en `pumpShell`, agrega la ruta después de `/roasts`:

```dart
        GoRoute(path: '/stats', builder: (_, _) => const Text('stats-page')),
```

Agrega este helper antes de `main()`:

```dart
List<String> labels(WidgetTester t) =>
    [for (final d in t.widgetList<NavigationDestination>(find.byType(NavigationDestination))) d.label];
```

Y estas pruebas dentro de `main()`:

```dart
  testWidgets('roaster ve Resumen después de Tuestes', (t) async {
    await pumpShell(t, const User(id: '1', email: 'r@x.com', name: 'Rita', role: 'roaster', active: true));
    expect(labels(t), ['Lotes', 'Tuestes', 'Resumen']);
  });

  testWidgets('admin ve Resumen entre Tuestes y Usuarios', (t) async {
    await pumpShell(t, const User(id: '2', email: 'a@x.com', name: 'Ada', role: 'admin', active: true));
    expect(labels(t), ['Lotes', 'Tuestes', 'Resumen', 'Usuarios']);
  });
```

- [ ] **Paso 2: comprobar que falla**

Ejecuta: `cd web && flutter test test/shell_test.dart`
Esperado: FAIL, porque falta 'Resumen' en la lista.

- [ ] **Paso 3: implementar**

`web/lib/shell.dart`: en `dests`, después de la línea de Tuestes:

```dart
      ('/stats', Icons.bar_chart, 'Resumen'),
```

`web/lib/router.dart`: agrega `import 'stats_screen.dart';` y, dentro del `ShellRoute`, antes de `/users`:

```dart
          GoRoute(path: '/stats', builder: (_, _) => const StatsScreen()),
```

La redirección de inicio sigue en `/lots` (CA-26), así que no la toques.

- [ ] **Paso 4: comprobar que pasa**

Ejecuta: `cd web && flutter test && flutter analyze`
Esperado: todo PASS y `No issues found!`.

- [ ] **Paso 5: commit**

```bash
git add web/lib/router.dart web/lib/shell.dart web/test/shell_test.dart
git commit -m "feat(web): add summary to navigation"
```

---

### Tarea 4: verificación final

Esta tarea no tiene código nuevo. Cumple la sección "Al terminar cualquier tarea" de `AGENTS.md`.

- [ ] **Paso 1:** `cd web && flutter analyze`. Esperado: `No issues found!`.
- [ ] **Paso 2:** `cd api && pytest` y `cd web && flutter test`. Esperado: todo PASS.
- [ ] **Paso 3:** `podman compose up --build -d`.
- [ ] **Paso 4:** comprueba que la imagen trae la base de zonas horarias:
  `podman compose exec api python -c "from zoneinfo import ZoneInfo; print(ZoneInfo('America/Argentina/Buenos_Aires'))"`.
  Si falla, agrega `"tzdata"` a `dependencies` en `api/pyproject.toml`, reconstruye y haz commit con `fix(api): bundle tzdata`.
- [ ] **Paso 5:** `curl -fsS http://localhost:8080/api/v1/health` devuelve `{"status":"ok"}`, y http://localhost:8080 carga.
- [ ] **Paso 6:** entra como admin, abre "Resumen" y comprueba que muestra el mes actual y que las flechas funcionan.
- [ ] **Paso 7:** escribe `specs/001-resumen-mensual/dev-notes.md` con lo que se desvió del plan (o "sin desvíos") y pasa a `qa`.
