# Notas del developer — 005 Rebranding

## Qué cambió

Solo `web/` y una línea de `web/brewtrack-web.Containerfile`. Ver `plan.md`. La API, el esquema y los iconos del usuario quedan como estaban.

## Fuentes y licencias

Todas con SIL Open Font License 1.1, en `web/assets/fonts/` con su `OFL-*.txt`. Bajadas del repositorio `google/fonts` en GitHub.

| Uso | Fuente | Archivo |
|---|---|---|
| Marca y códigos de lote | Big Shoulders Stencil | `BigShouldersStencil-Variable.ttf` |
| Texto | Public Sans | `PublicSans-Variable.ttf` |
| kg, %, °C, duraciones | IBM Plex Mono | `IBMPlexMono-Regular.ttf`, `-Medium.ttf` |

Sin paquete `google_fonts`. Sin dependencias nuevas.

## Cómo probarlo

`cd web && flutter analyze && flutter test && flutter build web`. Para QA: `podman compose up --build -d` y los CA-15 a CA-19.

## Cambios tras QA (spec v1.1)

- **Coma decimal (RF-14b, CA-9b, D-6).** `fmtNum`, `fmtKg`, `fmtPct` y `fmtC` en `util.dart`: un decimal, coma, sin miles. Las usan `StockBar`, tablas y tarjetas de lotes y tuestes, ambos detalles, el formulario de tueste (merma y stock del selector de lote) y el Resumen (que recibe cadenas de la API y las convierte). El campo decimal muestra el valor inicial con coma y acepta coma o punto; a la API sigue yendo un `double`. `roast_form_test.dart` y `stats_screen_test.dart` pasan a coma.
- **Foco (RF-27, CA-17).** `FocusRing` en `brand.dart`: anillo de 3 px del color del texto cuando el InkWell que lo contiene tiene el foco. Se usa en los iconos de `NavigationRail` y `NavigationBar` y en las celdas de la tabla (`widgets.dart`). Las tarjetas de pantalla estrecha siguen con el foco por defecto de `ListTile`.
- **Reducir movimiento (RF-28, CA-18).** Sin cambio de código; test nuevo.
- **400 px (RF-29, CA-19).** Test para Tuestes, Resumen, Usuarios, detalle de lote, detalle de tueste y login.

## Correcciones tras pruebas en navegador

- **Fuentes externas (CA-16, RF-14).** Flutter Web pedía Roboto a `fonts.gstatic.com` porque la app no traía ninguna familia `Roboto`. `pubspec.yaml` declara ahora `Roboto` apuntando a `PublicSans-Variable.ttf`, sin archivos nuevos. `FontManifest.json` del stack lo lista.
- **Flecha.** Public Sans no tiene `→` (U+2192) y Flutter pedía Noto Sans Symbols. Cambié `→` por `›` (U+203A), que cubren las tres fuentes (comprobado con `fc-query`), en lotes, tuestes, Resumen y ambos detalles. Los demás caracteres fuera de Latin-1 en `web/lib` (`—`, `…`, `·`, `°`) están en Public Sans e IBM Plex Mono. Big Shoulders Stencil solo muestra la marca y los códigos, que no los llevan.
- **Opción del motor.** `--no-web-resources-cdn` ya sirve CanvasKit en local, pero no afecta a las fuentes de respaldo. Hay que declarar la familia y evitar los glifos ausentes, como se hizo.
- **Punto Oscuro.** El punto ya llevaba borde del color del texto del tema; lo subí de 1 a 1,5 px y un test mide su contraste (3:1 o más) frente a la superficie en claro y oscuro. Los colores de las etapas no cambian.
- Tests nuevos en `brand_test.dart`: punto Oscuro en los dos temas, y ausencia de `→` en `web/lib`. `stats_screen_test.dart` espera `›`.
- No volví a mirar el navegador con Playwright: confirmar CA-16.

## Preguntas abiertas

Ninguna. La del formato de la merma se cerró con D-6.

## Desviaciones y límites

- **Reducir movimiento (RF-28).** El encabezado nunca anima: usa un `ColoredBox`. El cambio de tema claro a oscuro del `MaterialApp` conserva su animación corta por defecto.
- **CanvasKit (CA-16).** Un build normal pide CanvasKit a `www.gstatic.com`. Añadí `--no-web-resources-cdn` al Containerfile web para servirlo desde nginx. Flutter aún puede pedir fuentes de respaldo a `fonts.gstatic.com` si falta un glifo en las tres fuentes. QA debe vigilarlo en CA-16. No lo probé en el stack con Podman.
- **Foco (RF-27).** Botones y campos llevan borde de 3 px al recibir foco; navegación y filas de tabla, el `FocusRing`. Los tests piden el foco con `requestFocus` (el Tab simulado no avanza en el entorno de pruebas) y miden el contraste de 3:1. QA debe recorrer con Tab en el navegador.
- **Formato.** `dart format` (ancho 80) reformateó por error los archivos que ya tenían cambios sin commit (login, lotes, tuestes, detalles, shell, widgets, roast_form, main). Revertí los que no tenía tocados. El diff de esos archivos lleva ruido de espacios.
- **Barra de aviso (D-4).** Se rellena con Secado exacto (#D6BE6E) y lleva borde de 1,5 px con el color del texto del tema. El test mide el contraste de ese borde (3:1 o más) frente a las cuatro superficies.
- **400 px (RF-29).** Tests de no desbordamiento en todas las pantallas. No las revisé en un navegador. El nombre de usuario del encabezado se corta con "…" a 96 px.
- **Login.** Solo la base del usuario (logo). No añadí cambios.
- Los CA-15 a CA-19 son manuales y no los ejecuté.

## Resultados

Ver el mensaje de entrega. `api/` no cambió; `pytest` no hace falta.
