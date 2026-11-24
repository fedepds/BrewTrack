# Snyk: dependencias, vulnerabilidades críticas y correcciones

Informe de Snyk: `reports/snyk-report.txt`, generado con `SNYK_TOKEN=<token> scripts/snyk-scan.sh`.

## Qué se analiza

Las versiones exactas que instala `pip install ./api`, igual que el Containerfile. `pyproject.toml` pide rangos (`fastapi>=0.115`, …), así que Snyk analiza un `pip freeze` de una instalación real (`api/requirements-snyk.txt`) y no el archivo de rangos.

El frontend (Dart/pub) no tiene soporte en Snyk. Sus dependencias se revisan con `flutter pub outdated` (ver `docs/security/Semgrep.md`).

## Resultado

> **Pendiente:** completar con la salida de `scripts/snyk-scan.sh`. Desde el entorno donde se preparó esto no se llega a `api.snyk.io`.

Revisión previa con pip-audit, contra la base de vulnerabilidades de PyPI, sobre los mismos 36 paquetes (`reports/pip-audit-report.txt`): **ninguna vulnerabilidad conocida**.

| Severidad | Snyk (dependencias) | pip-audit |
|---|---|---|
| Crítica | _completar_ | 0 |
| Alta | _completar_ | 0 |
| Media / baja | _completar_ | 0 |

## Qué hace el pipeline con una crítica

La etapa *Snyk dependencias* corre con `--severity-threshold=critical`. Si aparece una vulnerabilidad crítica, Snyk sale con código 1, la etapa falla y no se construye ni se despliega nada. Las imágenes las revisa Trivy, que corta con HIGH y CRITICAL: un segundo escáner con un umbral más alto no frenaba nada nuevo. El informe queda en los artefactos del build.

## Correcciones propuestas

1. **Si Snyk marca una crítica en una dependencia directa** (por ejemplo `fastapi` o `pyjwt`): subir el mínimo en `api/pyproject.toml` a la versión que Snyk indica como arreglo (`Upgrade to …`), reconstruir la imagen y volver a correr `scripts/snyk-scan.sh`.
2. **Si es una dependencia transitiva** (por ejemplo `starlette` a través de `fastapi`): agregarla a `dependencies` con el mínimo arreglado, aunque no se importe directamente, hasta que la dependencia directa la suba.
3. **Fijar versiones.** Hoy cada build puede resolver versiones distintas porque `pyproject.toml` usa rangos. Propuesta: generar un lock con hashes (`uv pip compile pyproject.toml --generate-hashes -o requirements.lock` o `pip-compile`), instalar desde el lock en el Containerfile y escanear ese mismo archivo con Snyk. Así lo que se escanea es exactamente lo que se despliega.
4. **Imagen base de la API.** Trivy deja 47 avisos HIGH en paquetes de Debian sin arreglo publicado (`docs/security/revision_seguridad.md`). Para bajarlos sin esperar a Debian: pasar a una imagen base mínima (`gcr.io/distroless/python3` o una de Chainguard), que no trae shell ni la mayoría de esas bibliotecas. Hay que probar antes que `alembic upgrade head` siga funcionando sin `sh`.
