# Semgrep: hallazgos y qué hicimos con cada uno

Informe completo: `reports/semgrep-report.txt` (generado con `scripts/semgrep-scan.sh`).

## Cómo se corrió

- **Reglas de la comunidad** (repo `semgrep/semgrep-rules`): `python`, `dockerfile`, `yaml`, `generic/nginx` y `generic/secrets`. Son las mismas carpetas de la revisión anterior (`docs/security/revision_seguridad.md`).
- **Reglas propias** (`semgrep/python-security.yaml`): cinco reglas para el stack de la API. Cada una tiene casos de prueba en `semgrep/python-security.py`, y `semgrep --test` da 5/5.

| Regla propia | Detecta | CWE |
|---|---|---|
| `brewtrack-jwt-decode-sin-verificar` | `jwt.decode` sin `algorithms`, con la firma apagada o aceptando `none` | CWE-347 |
| `brewtrack-sql-armado-con-texto` | `text()` o `execute()` con f-string, `%`, `.format` o `+` | CWE-89 |
| `brewtrack-like-sin-escape` | `like()`/`ilike()` con un patrón armado desde una variable | CWE-943 |
| `brewtrack-hash-debil-para-claves` | `hashlib.md5`, `hashlib.sha1` | CWE-327 |
| `brewtrack-secreto-en-log` | `print` o `log.*` con `jwt_secret`, contraseñas o tokens | CWE-532 |

Las reglas de JWT, SQL y secretos en logs no encontraron nada. Quedan como guardia: el pipeline corta si alguien escribe código así.

## Resultado

| Corrida | Hallazgos |
|---|---|
| Reglas propias sobre el código original de la API | 2 (LIKE sin escape) |
| Escaneo completo, primera corrida (con el LIKE ya corregido) | 37 (102 líneas marcadas) |
| Escaneo completo, después de los cambios | **1, falso positivo** |

### 1. LIKE sin escape en el filtro de lotes: corregido

`brewtrack-like-sin-escape` marcó dos líneas en `api/app/routers/green_lots.py`:

```python
where.append(GreenLot.origin_country.ilike(f"%{country}%"))
where.append(GreenLot.process.ilike(f"%{process}%"))
```

No es inyección SQL: SQLAlchemy manda el valor como parámetro. Pero `%` y `_` son comodines de LIKE, y el usuario los puede mandar. Con `?country=%` la API devolvía todos los lotes, y un patrón como `%_%_%_%…` obliga a Postgres a recorrer toda la tabla.

**Arreglo:** `icontains(valor, autoescape=True)`, que escapa los comodines y sigue sin distinguir mayúsculas.

**Prueba:** `test_filter_treats_like_wildcards_as_text` (`api/tests/test_green_lots.py`). Falla con el código viejo (`?country=%` traía 2 lotes) y pasa con el nuevo. La suite completa da 120 tests en verde.

### 2. `no-fractional-cpu-limits` (8 líneas): corregido

Los límites de CPU de 0,2 y 0,5 núcleos hacen que Kubernetes frene el proceso aunque el nodo tenga CPU libre. Subimos el `limit` a 1 núcleo en la chart (`values*.yaml`), Prometheus y Grafana.

Esto no reserva más CPU: lo que reserva son los `requests`, que siguen en 0,05–0,25. Kyverno sigue exigiendo un límite (política 02), así que un pod no puede quedarse con todo el nodo.

### 3. `metadata-*` en las reglas propias (93 líneas): corregido

Son reglas de la comunidad que revisan que una regla de Semgrep tenga la metadata del registro: `confidence`, `likelihood`, `impact`, `subcategory`, `technology`, `references` y `owasp` en formato `A0X:2021`. La agregamos a las cinco reglas.

### 4. `facebook-page-access-token` en `web/pubspec.lock`: falso positivo, justificado

```
172┆ sha256: eaac480a35ec0814146c2c48d96aaa829e0e44a7662c88ae84c9edf4bc35651f
```

Es el hash sha256 de un paquete de Dart. `flutter pub get` lo escribe para comprobar que el paquete no cambió. La regla de gitleaks busca cadenas largas en hexadecimal y no distingue un hash de un token.

No lo excluimos del escaneo: `pubspec.lock` se regenera y cualquier secreto real que apareciera ahí tiene que verse. La revisión anterior ya lo había marcado como falso positivo.

## En el pipeline

La etapa Semgrep del `Jenkinsfile` corre los paquetes `p/python`, `p/security-audit`, `p/secrets` y `p/dockerfile` más las reglas propias, con `--error`. Si hay un hallazgo, el pipeline se detiene.
