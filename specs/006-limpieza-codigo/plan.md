# 006 — Plan

## Constitución

| Regla | Cómo la cumple este cambio |
|---|---|
| Alcance | Solo borra y unifica. No suma funciones, pantallas ni endpoints. |
| Stock | Sigue sin columna ni valor guardado. Pasa a una expresión SQL en `GreenLot` que se evalúa en cada lectura. Tras cada escritura se relee con `db.refresh` (RF-6). |
| Permisos | Ningún `Depends` ni rol cambia. Los tests de roles actuales corren sin cambios. |
| Errores | Los 409 de `insufficient_stock` conservan código y mensaje: `_check_stock` y `used_kg(..., exclude)` no cambian. |
| Esquema | Sin migraciones. El `column_property` no crea columna; `alembic upgrade head` no cambia. |
| Secretos | `JWT_SECRET` sigue por entorno. Solo salen del entorno dos duraciones que no son secretas. Nadie lee `.env`. |

## Diseño

### Stock (RF-3 a RF-8)

Hoy el stock se calcula en cuatro sitios más `stats.py`:
- `_with_stock` y `create_lot` en `green_lots.py` asignan `lot.stock_kg` a mano.
- `list_lots` suma con `used_expr()` y asigna `lot.stock_kg = s` fila por fila.
- `get_roast` en `roasts.py` asigna `roast.lot.stock_kg`.
- `stats.py` usa `used_expr()` en SQL.

El cambio:

1. **Definición única.** `api/app/models.py` añade, después de la clase `Roast` (necesita `Roast.green_in_kg`):
   ```python
   GreenLot.stock_kg = column_property(
       GreenLot.received_kg
       - select(func.coalesce(func.sum(Roast.green_in_kg), 0))
       .where(Roast.lot_id == GreenLot.id).correlate_except(Roast).scalar_subquery()
   )
   ```
   Cada `select(GreenLot)` trae el stock en la misma consulta, también el lote que `Roast.lot` carga con `lazy="joined"`. A nivel de clase, `GreenLot.stock_kg` es la expresión SQL y `stats.py` la usa tal cual.
2. **Lecturas.** `list_lots` pasa a `db.scalars(select(GreenLot)...)` sin columna extra ni bucle. `get_lot` y `get_roast` devuelven el objeto: el valor ya viene cargado.
3. **Escrituras.** Con `expire_on_commit=False` (`db.py`), el objeto conserva tras el `commit` el stock que leyó antes. Por eso `create_lot` y `patch_lot` llaman `db.refresh(lot)` después de `commit_or_409`. `refresh` sin argumentos vuelve a leer también la propiedad calculada. `get_lot`, `get_roast` y `list_lots` no necesitan nada: cada petición abre una sesión nueva, sin objetos previos. Las respuestas de `POST`, `PATCH` y `DELETE` de tuestes (`RoastOut`) no llevan `stock_kg`.
4. **Validación.** `used_kg(db, lot_id, exclude_roast_id)` queda en `stock.py` solo para validar. `GreenLot.stock_kg` es la única expresión de lectura (RF-8). No se puede sustituir por `lot.stock_kg`: la validación necesita excluir el tueste que se edita, y `seed_roasts` llama `_check_stock` entre `flush` y `flush` sobre lotes ya cargados, así que su `stock_kg` estaría viejo. `used_expr` se borra. `_check_stock`, el chequeo de `patch_lot` y `seed.py` no cambian.
5. **Comentario de `LotOut`.** En `schemas.py` el comentario "se asigna como atributo transitorio" ya no es cierto; se corrige. Los tipos no cambian, así que el `openapi.json` tampoco.

Riesgo: sin `refresh`, `PATCH` devolvería el stock anterior. CA-9 y CA-10 lo detectan.

Coste: cada carga de `GreenLot` ejecuta la subconsulta, incluido el lote de cada fila de `list_roasts`. Con un taller y 200 filas por página no importa; la spec deja fuera el rendimiento.

### Tokens (RF-9)

`security.py` usa `timedelta(minutes=60)` y `timedelta(days=7)` en dos constantes del módulo. `config.py` pierde `access_ttl_min` y `refresh_ttl_days`. Ni `compose.yaml`, ni `.env.example`, ni `k8s/` fijan esas variables (comprobado con `grep`).

### Frontend (RF-10 a RF-12)

- `pubspec.yaml`: se borran los comentarios de la plantilla y `cupertino_icons`. Queda `uses-material-design: true`. `flutter pub get` regenera `pubspec.lock`.
- `web/README.md` se borra.
- `Paged<T>` y `pageFrom` salen de `models.dart`. `api.dart` pasa a `Future<List<Lot>> lots(...)` y `Future<List<Roast>> roasts(...)`, con `[for (final i in (await _get(...))['items']) Lot.fromJson(i)]`. En `providers.dart`, `lotsProvider` y `roastsProvider` devuelven `List<Lot>` y `List<Roast>`. Se quitan `.items` en `roast_form.dart`, `roasts_screen.dart` (dos sitios) y `lots_screen.dart`. El nombre `page` en los `when(data: (page) ...)` pasa a `items`. Los tests de widgets no nombran `Paged`; si alguno sobrescribe `lotsProvider`, se ajusta el tipo sin cambiar lo que comprueba.

### Imagen web (RF-13 a RF-16)

- `brewtrack-web.Containerfile`: se borra la línea `COPY ... 10-api-host.envsh` y se añade `ENV API_HOST=api` junto a `ENV NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1`. El entrypoint de nginx aplica `envsubst` a `templates/` con el entorno del contenedor, así que `-e API_HOST=otrohost` y el `env:` de `k8s/brewtrack.yaml` mandan sobre `ENV`.
- Se borra `web/docker-entrypoint.d/` (queda vacío).
- `k8s/README.md` línea 147 no nombra el script; el texto sigue cierto y no cambia.
- Etiqueta: la imagen `web` cambia, así que sube de `0.1.1` a `0.1.2` en `compose.yaml` (línea 39), en `k8s/brewtrack.yaml` (línea 122) y en los comandos de `k8s/README.md` (líneas 12 y 19; la 68 y la 69 usan `<nueva>`).

## Datos

Sin migraciones. El esquema no cambia.

## Orden

Primero los tests de stock y de tokens, que pasan contra el código actual. Después la API (stock, tokens), el frontend, la imagen y la verificación completa.
