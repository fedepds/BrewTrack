# Plan 005 — Rebranding visual

Solo cambia `web/`. Sin API, esquema, permisos ni datos nuevos. Ninguna dependencia nueva.

## Constitución

| Regla | Cómo la cumple este cambio |
|---|---|
| Alcance | Solo presentación de lotes y tuestes. Las etapas son una escala de color. |
| Stock calculado | `StockBar` usa `stock_kg` y `received_kg` de la API. No calcula ni guarda stock. |
| Permisos en la API | `Shell` sigue ocultando Usuarios a `roaster`. La API no cambia. |
| Errores | Sin endpoints nuevos. |
| Migraciones | Sin cambios de esquema. |
| Secretos | Ninguno. Las fuentes van como archivos en `web/assets/fonts/`. |

## Diseño

- `lib/brand.dart` (nuevo): etapas y `stageColor`/`stageName`, `onColor` (negro o blanco por contraste WCAG), `contrast`, `levelColor`, estilos `stencil` y `mono`, `brandTheme(brightness)`, y los widgets `RatioBar`, `StockBar` y `LevelChip`.
- `lib/main.dart`: `theme` y `darkTheme` con `brandTheme`. El modo sigue al sistema (`ThemeMode.system` por defecto).
- `lib/shell.dart`: `ConsumerStatefulWidget`. Un `NotificationListener` sobre el contenido calcula el avance con el scroll vertical de profundidad 0 y con `ScrollMetricsNotification` (da avance 0 al cargar una pantalla sin scroll). El avance guarda la ruta, así que el de otra pantalla cuenta como 0. El fondo es un `ColoredBox` y no el color del `AppBar`, que anima. Barra lateral (`NavigationRail`) desde 760 px, inferior por debajo.
- `lib/widgets.dart`: `ResponsiveTable` acepta celdas `String` o `Widget`, título como `Widget`, `cardExtra` y `empty`. Nuevo `EmptyState`.
- `lib/lots_screen.dart`, `roasts_screen.dart`: listas vacías con "Quitar filtros" o botón de alta.
- `lib/roast_form.dart`: el pie del formulario añade las barras Entra y Sale y el aviso.
- Detalles de lote y de tueste: `StockBar`, `LevelChip`, códigos en stencil, cifras en mono.
- `pubspec.yaml`: familias `BigShouldersStencil`, `PublicSans`, `IBMPlexMono`.
- `brewtrack-web.Containerfile`: `--no-web-resources-cdn` para que CanvasKit salga de nginx y no de gstatic.com.

## Pantallas afectadas

Todas las de sesión (encabezado y navegación), Lotes, Tuestes, detalle de lote, detalle de tueste, formulario de tueste. Login sin cambios de código.
