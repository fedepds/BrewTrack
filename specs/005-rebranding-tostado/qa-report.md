# Informe de QA — spec 005 (v1.1)

Rama: `feat/005-rebranding-tostado` (cambios sin commit). Fecha: 2026-10-15. Segunda ronda.

## Veredicto: APROBADO

Los 22 criterios pasan (CA-1 a CA-21 y CA-9b). Sin violaciones de la constitución ni fallos abiertos. La primera ronda pedía cambios (CA-9 y CA-15 a CA-19 sin cerrar); la spec v1.1 y el developer los resolvieron.

## Criterios de aceptación

| CA | Resultado | Evidencia |
|---|---|---|
| CA-1, CA-2, CA-3, CA-4, CA-5 | Cumple | `shell_test.dart` (CA-1/2/3, CA-4, CA-5). Navegador: colores del encabezado al bajar por Lotes `#9FA57A` → `#CBA85F` → `#8F5B32` → `#3D2519` → `#3A2318`; etiqueta de "Verde" a "Oscuro" (coordinador, Playwright). |
| CA-6 | Cumple | `brand_test.dart` (chip en lista y detalle; punto Oscuro con 3:1 en los dos temas, borde de 1,5 px). |
| CA-7 | Cumple | `brand_test.dart` (barra al 50 %, "30,0 kg", texto para lectores de pantalla). |
| CA-8, CA-8b | Cumple | `brand_test.dart` (#D6BE6E bajo el 15 %, borde con 3:1 frente a las cuatro superficies). |
| CA-9 | Cumple | Barras y #3A2318 en `brand_test.dart`; "15,0 %" por `fmtPct` (`util.dart:15`, `roast_form.dart:48`). |
| CA-9b | Cumple | `brand_test.dart:397` (lotes, tuestes, formulario; sin "10.000 kg" ni punto). `roast_form_test.dart:35` escribe `8.5` y obtiene la misma merma. Coma en `fmtNum`/`fmtKg`/`fmtPct`/`fmtC` y en Resumen (`stats_screen.dart:66`). |
| CA-10, CA-11, CA-12 | Cumple | `brand_test.dart`. |
| CA-13, CA-14 | Cumple | `shell_test.dart:159` y barra lateral/inferior. La lista de destinos y `isAdmin` no cambiaron. |
| CA-15 | Cumple | Coordinador, Playwright con `prefers-color-scheme: dark`: login, Lotes, Tuestes, Resumen, Usuarios y formulario de tueste siguen el tema oscuro. Código: `theme` y `darkTheme` sin `themeMode` fijo. No lo repetí yo en el navegador. |
| CA-16 | Cumple | Coordinador, caché y localStorage vacíos: login, Lotes, Tuestes, Resumen y Usuarios con datos reales, cero peticiones fuera de `localhost:8080`. Arreglos verificados en el diff: familia `Roboto` apuntando a Public Sans (`pubspec.yaml:34`), `→` cambiado por `›` (test `brand_test.dart:149`; solo queda en un comentario de `util.dart:26`), `--no-web-resources-cdn` (`brewtrack-web.Containerfile:6`). La cadena `fonts.gstatic.com/s/` sigue en `main.dart.js`, pero no se pide. |
| CA-17 | Cumple | Coordinador: el anillo de foco aparece con Tab en "Entrar" y en las celdas de la tabla de tuestes. `FocusRing` presente en `shell.dart:135`, `:152` y `widgets.dart:110`. Límite: el recorrido completo con Tab por el rail no se grabó aparte. |
| CA-18 | Cumple | Test `shell_test.dart:226` y Playwright con `reducedMotion: reduce`: cambio sin animación. |
| CA-19 | Cumple | Tests a 400 px de todas las pantallas (`brand_test.dart:349`, `:483`; `shell_test.dart:173`). Coordinador: `scrollWidth` 400 en lots, roasts, stats y users; login correcto. |
| CA-20 | Cumple | `git diff master -- api` vacío; 2 migraciones, ninguna nueva. Logo e iconos son los del árbol de trabajo del usuario. No tengo los originales para comparar byte a byte. |
| CA-21 | Cumple | `flutter analyze`: sin problemas. `flutter test`: 38 pasan (yo, de nuevo). `pytest`: 107 pasan en la primera ronda con un Postgres temporal; `api/` no cambió desde entonces. |

## Constitución

| Regla | Resultado | Evidencia |
|---|---|---|
| Sin columna de stock | Pasa | `api/` sin cambios. |
| Stock de la API | Pasa | `StockBar` usa `stockKg` y `receivedKg` de la API. |
| Permisos en la API | Pasa | Sin endpoints nuevos; la web solo oculta (CA-14). |
| Formato de error | No aplica | Sin endpoints nuevos. |
| Migración nueva | No aplica | Sin cambios de esquema. |
| Sin credenciales ni `.env` | Pasa | No leí `.env`. Semgrep y Trivy sin secretos. El usuario admin temporal de las pruebas ya se borró. |
| Imagen `api` sin root y `/health` | Pasa | `api/` sin cambios; `/health` 200. |
| Imagen `web` sin root (spec 004) | Pasa | `security-report.md`. |
| Sin nada fuera de alcance | Pasa | Solo presentación. |
| Idioma de los comentarios | Pendiente de revisión humana | Aprueba el PR Federico Pizarro. |

## Fallos

Ninguno abierto. Resueltos desde la primera ronda: formato decimal (D-6), flag `--no-web-resources-cdn` (D-5), peticiones a `fonts.gstatic.com` (Roboto y Noto Sans Symbols), foco de navegación y tablas, test de RF-28, tests de 400 px.

## Criterios sin prueba

- Recorrido completo con Tab por el rail y la barra inferior (CA-17): solo se vio en "Entrar" y la tabla de tuestes.
- Comparación byte a byte de logo e iconos (CA-20).
- Las pruebas de navegador las hizo el coordinador, no yo.

## Seguridad

Veredicto de `security-report.md`: APROBADO, sin bloqueantes. El hallazgo bajo de `fonts.gstatic.com` queda cerrado en la práctica (CA-16: cero peticiones externas). Los cambios posteriores a ese informe (Roboto, `›`, `FocusRing`, formato) no tocan nginx, dependencias ni secretos; no volví a ejecutar Semgrep ni Trivy sobre ellos.

## Observaciones fuera de la spec (no bloquean)

1. El logo PNG tiene fondo crema opaco; en tema oscuro se ve un rectángulo claro.
2. Con un refresh token de un usuario que ya no existe, la app muestra la shell con el nombre antiguo y todas las llamadas dan 401, en vez de volver al login. Es previo a esta spec; propongo una spec aparte.
3. nginx sin cabeceras de seguridad (deuda previa de security).
4. Las capturas están en `.playwright-mcp/`, sin seguimiento en git: no commitear.
