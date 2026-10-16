# 005 — Rebranding visual: la identidad del tueste

Estado: aceptada
Fecha: 2026-10-15

## Contexto y objetivo

Hoy el tema de la web sale de un solo color semilla marrón de Material 3. La app no se distingue de cualquier otra y no dice nada del oficio del taller.

La identidad nueva se basa en el tueste del grano: del verde crudo al oscuro. El usuario ya vio una maqueta HTML (https://claude.ai/artifact/3k8eNLYQSoQ63UtmoezaWA) y pidió esta spec.

El usuario ya preparó un logo nuevo, aún sin commitear: `web/assets/logo.png`, `web/assets/bean.png`, y el favicon y los iconos de `web/web/`. Esta spec parte de esos archivos y no los reemplaza.

Objetivo: que la web muestre la identidad del tueste en color, letra y gráficos, y que siga haciendo lo mismo que hoy. Es un cambio solo de interfaz: no toca la API, el esquema, los permisos ni los datos. El stock que se ve sigue siendo el que calcula la API.

## Historias de usuario

- HU-1. Como `roaster`, quiero que el encabezado cambie de color mientras bajo por una lista, del verde al oscuro, para reconocer la app y saber cuánto me falta de la lista.
- HU-2. Como `roaster`, quiero ver el nivel de un tueste como un chip de color con su nombre, para leer la lista de tuestes de un vistazo.
- HU-3. Como `roaster`, quiero ver una barra de stock en cada lote y un aviso cuando queda poco, para saber qué lotes se acaban.
- HU-4. Como `roaster`, quiero ver en el formulario de tueste cuánto entra y cuánto sale en barras, para detectar un error de pesaje antes de guardar.
- HU-5. Como `roaster`, quiero que una lista vacía me diga si la vacían mis filtros y me deje quitarlos con un botón.
- HU-6. Como `admin`, quiero que la app siga la preferencia de modo oscuro del sistema, para trabajar de noche en el taller sin una pantalla blanca.
- HU-7. Como `admin`, quiero que la app funcione con teclado, con "reducir movimiento" y en un móvil de 400 px, para que nadie del taller quede fuera.

## Requisitos funcionales

### Etapas de tueste

Cinco etapas, en este orden, con colores fijos. Estos colores no cambian con el tema claro u oscuro.

| Etapa | Color |
|---|---|
| Verde | #9FA57A |
| Secado | #D6BE6E |
| Canela | #B5793F |
| Medio | #7A4A2A |
| Oscuro | #3A2318 |

### Encabezado que se tuesta

- RF-1. El color de fondo del encabezado depende de cuánto ha bajado el contenido principal de la pantalla. Llamamos "avance" a la parte recorrida: 0 arriba del todo, 1 al final.
- RF-2. Con avance 0 el fondo es Verde, con 0,25 Secado, con 0,5 Canela, con 0,75 Medio y con 1 Oscuro. Entre dos etapas, el color pasa de forma continua de una a otra, sin saltos.
- RF-3. Si el contenido no hace scroll, el fondo queda en Verde.
- RF-4. Junto al nombre de la marca, una etiqueta muestra el nombre de la etapa más cercana al avance actual (por ejemplo, "Canela" con avance 0,55).
- RF-5. El texto y los iconos del encabezado son negro puro (#000000) o blanco puro (#FFFFFF). En cada punto del recorrido usan el de los dos que da más contraste con el fondo. Así, de 0 a 1, el contraste es de 4,5:1 o más (WCAG AA). El resto de la app usa los colores de texto de la paleta (D-3).
- RF-6. El encabezado se comporta así en todas las pantallas con sesión: Lotes, Tuestes, Resumen, Usuarios, detalle de lote y detalle de tueste. Al cambiar de pantalla, el avance vuelve a contar desde la posición de la pantalla nueva.

### Paleta y modo oscuro

- RF-7. Tema claro: fondo #EEF0E6, superficie #F8F9F3, texto #2B1D14, acento #A86A33.
- RF-8. Tema oscuro: fondo #1A1511, superficie #241D17, texto #EDE6DA, acento #D19256.
- RF-9. La app usa el tema claro u oscuro según la preferencia del sistema, y cambia si esa preferencia cambia con la app abierta. La app no ofrece un selector propio (D-2).
- RF-10. El texto general cumple un contraste de 4,5:1 o más sobre el fondo y la superficie, en los dos temas.

### Tipografía

- RF-11. El nombre de la marca y los códigos de lote (por ejemplo, `GL-2026-014`) usan una letra stencil, del estilo de las marcas en los sacos de café.
- RF-12. El resto del texto usa una letra sans.
- RF-13. Los kg, los %, las temperaturas y las duraciones usan una letra monoespaciada con cifras de ancho fijo, para que las columnas de números queden alineadas.
- RF-14. Las tres fuentes van dentro de la app. Al cargar o usar la app, el navegador no pide fuentes a ningún otro servidor. Las fuentes tienen una licencia que permite incluirlas en la app; el developer anota cuáles usa y su licencia en `dev-notes.md`. El build de la web usa recursos locales: el motor de dibujo de Flutter (CanvasKit) también sale del contenedor `web`, no de un CDN de Flutter (D-5).

### Formato de números

- RF-14b. Todas las pantallas escriben los decimales con coma: kg, %, °C y duraciones con decimales. Los kg y los % llevan un decimal (`30,0 kg`, `15,0 %`), también en las tablas y tarjetas de lotes y tuestes, que hoy muestran `10.000 kg`. Los números no llevan separador de miles, para que el punto no se confunda con la coma. Los campos numéricos de los formularios aceptan coma y punto como separador decimal (D-6).

### Nivel de tueste en color

- RF-15. En listas y detalles, el nivel de tueste se muestra como un chip con un punto de color y el nombre del nivel en texto: claro con el color Canela, medio con Medio y oscuro con Oscuro. El nombre siempre se ve; el color nunca va solo.

### Barra de stock

- RF-16. Cada lote, en la lista de lotes y en su detalle, muestra una barra con la parte del stock sobre lo recibido, junto a la cifra de stock en kg. Los dos valores salen de la API.
- RF-17. Si el stock es menor que el 15 % de lo recibido, la barra usa el color Secado como aviso (D-1).
- RF-17b. En los dos temas, la barra de aviso se distingue del fondo que la rodea: su relleno o su borde tiene un contraste de 3:1 o más frente a ese fondo (WCAG 1.4.11). El developer elige si oscurece la barra o le añade un borde (D-4).
- RF-18. La barra tiene un texto para lectores de pantalla con la forma "Quedan N % de lo recibido", con N redondeado a un entero.

### Merma en vivo con barras

- RF-19. En el formulario de tueste, cuando los dos pesos son mayores que 0, se ven dos barras, "Entra" y "Sale", además del % de merma que ya se muestra hoy. La barra "Entra" ocupa el ancho entero; la barra "Sale" ocupa la parte que sale sobre lo que entra.
- RF-20. La barra "Sale" toma el color del nivel elegido en el formulario (claro Canela, medio Medio, oscuro Oscuro).
- RF-21. Si sale más de lo que entra, el formulario muestra el aviso "Sale más café del que entra" en lugar del %. Este aviso no sustituye la validación de la API, que sigue rechazando el tueste.

### Navegación

- RF-22. Con una ventana de 760 px de ancho o más, la navegación va en una barra lateral. Con menos de 760 px, va en una barra inferior.
- RF-23. Las rutas que ve cada rol no cambian: los dos roles ven Lotes, Tuestes y Resumen; solo `admin` ve Usuarios.

### Listas vacías

- RF-24. En las listas de lotes y de tuestes, si los filtros no dan resultados, la lista dice qué pasó ("Ningún lote coincide con estos filtros" o "Ningún tueste coincide con estos filtros") y ofrece un botón "Quitar filtros".
- RF-25. "Quitar filtros" deja todos los filtros vacíos y vuelve a cargar la lista sin filtros.
- RF-26. Sin filtros y sin datos, la lista invita a crear el primero ("Aún no hay lotes" o "Aún no hay tuestes") con un botón que abre el formulario de alta.

### Calidad mínima

- RF-27. Todo elemento que recibe el foco del teclado muestra un indicador visible, con un contraste de 3:1 o más frente a lo que lo rodea.
- RF-28. Con "reducir movimiento" activo en el sistema, la app no anima los cambios de color: el encabezado toma el color nuevo en el mismo cuadro, sin transición.
- RF-29. Con 400 px de ancho, ninguna pantalla con sesión ni el login necesita scroll horizontal ni corta contenido.

### Base y alcance del cambio

- RF-30. La app usa el logo, el favicon y los iconos que dejó el usuario en `web/assets/` y `web/web/`, sin cambiarlos.
- RF-31. La API y sus respuestas no cambian. La app no calcula ni guarda stock propio: la barra de stock usa el stock y lo recibido que devuelve la API.
- RF-32. Hay tests de widgets nuevos para: color del encabezado con avance 0 y 1; cambio del color del texto del encabezado; chip de nivel con su nombre; barra de stock y su aviso bajo el 15 %, con su contraste de 3:1 o más; barras de merma y aviso cuando sale más de lo que entra; "Quitar filtros"; barra lateral o inferior según el ancho; y visibilidad por rol; y formato con coma (CA-9b). Los tests de widgets que ya existen siguen pasando, salvo los que exigen el punto decimal (por ejemplo, `15.0 %` en el test previo del formulario de tueste): esos se actualizan a la coma.

## Criterios de aceptación

CA-1 a CA-14 son tests de widgets (`cd web && flutter test`). CA-15 a CA-20 son pruebas manuales de QA sobre el stack levantado con `podman compose up --build -d`.

- CA-1. Dada la lista de lotes con más lotes de los que caben, cuando el avance es 0, entonces el fondo del encabezado es #9FA57A y la etiqueta dice "Verde".
- CA-2. Dada la misma lista, cuando el test baja hasta el final (avance 1), entonces el fondo del encabezado es #3A2318 y la etiqueta dice "Oscuro".
- CA-3. Dada la misma lista, cuando el avance es 0,5, entonces el fondo es #B5793F y la etiqueta dice "Canela".
- CA-4. Dada una lista que cabe entera sin scroll, cuando se muestra, entonces el fondo del encabezado es #9FA57A.
- CA-5. Dado el encabezado con avance 0, cuando el test lo compara con el avance 1, entonces el título y los iconos son #000000 en el primero y #FFFFFF en el segundo. Y para avances de 0 a 1 en pasos de 0,05, el título es #000000 o #FFFFFF, es el de los dos con más contraste frente al fondo, y ese contraste es de 4,5:1 o más.
- CA-6. Dado un tueste de nivel medio, cuando se muestra en la lista de tuestes y en su detalle, entonces se ve un chip con el texto "Medio" y un punto de color #7A4A2A. Lo mismo para claro (#B5793F) y oscuro (#3A2318) con sus nombres.
- CA-7. Dado un lote con 60 kg recibidos y 30 kg de stock según la API, cuando se muestra en la lista y en su detalle, entonces la barra está llena al 50 %, se ve "30,0 kg" y el texto para lectores de pantalla dice "Quedan 50 % de lo recibido".
- CA-8. Dado un lote con 100 kg recibidos y 14 kg de stock, cuando se muestra, entonces la barra usa #D6BE6E. Con 100 kg recibidos y 15 kg de stock, la barra no usa #D6BE6E.
- CA-8b. Dado el lote de CA-8 con 14 kg de stock, cuando se muestra en el tema claro y en el oscuro, entonces el relleno o el borde de la barra de aviso tiene un contraste de 3:1 o más frente al fondo sobre el que se dibuja (#F8F9F3 o #EEF0E6 en claro, #241D17 o #1A1511 en oscuro).
- CA-9. Dado el formulario de tueste con 10 kg de entrada, 8,5 kg de salida y nivel oscuro, cuando se muestra, entonces se ven las barras "Entra" (100 %) y "Sale" (85 %), la barra "Sale" es #3A2318 y se ve "15,0 %".
- CA-9b. Dado un lote con 10 kg recibidos y 10 kg de stock, y un tueste de 10 kg de entrada, 8,5 kg de salida y 205,5 °C, cuando se muestran la lista de lotes, el detalle del lote, la lista de tuestes, el detalle del tueste y el formulario de tueste, entonces se ven "10,0 kg", "8,5 kg", "15,0 %" y "205,5 °C", y en ninguna de esas pantallas aparece "10.000 kg", "15.0 %" ni otro número con punto decimal. Cuando el usuario escribe "8,5" o "8.5" en la salida del formulario, entonces la merma es "15,0 %" en los dos casos.
- CA-10. Dado el formulario de tueste con 10 kg de entrada y 11 kg de salida, cuando se muestra, entonces se ve "Sale más café del que entra" y no se ve ningún %.
- CA-11. Dada la lista de lotes con el filtro de país "Narnia" y sin resultados, cuando se muestra, entonces se ve "Ningún lote coincide con estos filtros" y un botón "Quitar filtros". Cuando el usuario lo pulsa, entonces los filtros quedan vacíos y la lista pide los lotes sin filtros. Lo mismo en la lista de tuestes con "Ningún tueste coincide con estos filtros".
- CA-12. Dada la lista de lotes sin filtros y sin datos, cuando se muestra, entonces se ve "Aún no hay lotes" y un botón que abre el formulario de alta. Lo mismo para tuestes.
- CA-13. Dada una ventana de 1024 px de ancho, cuando se muestra una pantalla con sesión, entonces se ve la barra lateral y no la inferior. Con 759 px, se ve la barra inferior y no la lateral.
- CA-14. Dado un usuario `roaster`, cuando se muestra la navegación con 1024 px y con 400 px, entonces se ven Lotes, Tuestes y Resumen, y no se ve Usuarios. Con un `admin`, se ven los cuatro.
- CA-15. Dado el sistema con modo oscuro, cuando QA abre la app, entonces el fondo es #1A1511 y el texto #EDE6DA. Cuando QA cambia el sistema a modo claro con la app abierta, entonces el fondo pasa a #EEF0E6 y el texto a #2B1D14 sin recargar. En los dos temas, los colores de las etapas son los de la tabla.
- CA-16. Dada la app recién cargada sin caché, cuando QA entra, recorre todas las pantallas con sesión y mira las peticiones del navegador, entonces ninguna petición de fuentes ni del motor de Flutter (CanvasKit) va a un servidor distinto de http://localhost:8080. El nombre de la marca y los códigos de lote se ven en letra stencil, y los kg y % en letra monoespaciada.
- CA-17. Dada cualquier pantalla con sesión, cuando QA la recorre solo con Tab, entonces cada elemento con foco muestra un indicador visible.
- CA-18. Dado "reducir movimiento" activo en el sistema, cuando QA baja por la lista de lotes, entonces el color del encabezado cambia sin transición animada.
- CA-19. Dada una ventana de 400 px de ancho, cuando QA abre el login y cada pantalla con sesión, entonces ninguna tiene scroll horizontal ni contenido cortado.
- CA-20. Dado el código de la entrega, cuando QA compara `openapi.json` con el de `master` y revisa `api/alembic/versions/`, entonces el contrato es igual y no hay migraciones nuevas. Cuando QA revisa `web/assets/logo.png`, `web/assets/bean.png` y los iconos de `web/web/`, entonces son los que dejó el usuario.
- CA-21. Dado el código de la entrega, cuando se ejecutan `cd web && flutter analyze`, `cd web && flutter test` y `cd api && pytest`, entonces pasan, incluidos los tests nuevos de RF-32.

## Chequeo de constitución

- **Alcance:** aplica. Cambia solo la presentación de lotes y tuestes del mismo taller. No toca curvas, empaque, venta, recetas, cata ni multi-empresa. Las "etapas de tueste" del encabezado son solo una escala de color, no datos de curva.
- **Stock calculado:** aplica. La barra muestra el stock y lo recibido que devuelve la API. La app no calcula ni guarda un stock propio (RF-31).
- **Permisos en la API:** aplica. La API sigue imponiendo los permisos. La web solo oculta lo que el rol no permite, como hoy (RF-23, CA-14).
- **Formato de error:** no aplica. No hay endpoints nuevos. Los errores 409 y 422 se siguen mostrando con el mensaje del backend, que llega como `{"error": {"code", "message"}}`.
- **Migraciones:** no aplica. No cambia el esquema (CA-20).
- **Secretos:** no aplica. No entra ningún secreto nuevo. Las fuentes van dentro de la app y no necesitan claves de ningún servicio.

## Fuera de alcance

- Cambios de API o de esquema.
- Pantallas nuevas.
- Rediseño del logo, el favicon o los iconos.
- Selector manual de tema dentro de la app.
- Pruebas de integración o de contraste automáticas en el navegador (la constitución deja fuera los tests de integración en v1).

## Decisiones

D-1 a D-4 las tomó el usuario el 2026-10-15, al responder las preguntas abiertas del borrador. D-5 y D-6 salen del informe de QA del mismo día.

- D-1. **Umbral del aviso de stock.** Se queda en el 15 % de lo recibido (RF-17, CA-8).
- D-2. **Modo oscuro.** Entra en esta spec y sigue la preferencia del sistema (RF-8, RF-9, CA-15).
- D-3. **Texto del encabezado.** El texto de la paleta (#2B1D14) sobre Canela da unos 4,48:1, y #EDE6DA no llega entre Canela y Medio. Por eso el encabezado usa negro puro o blanco puro, el que dé más contraste en cada punto. El resto de la app usa la paleta (RF-5, CA-5).
- D-4. **Aviso de stock visible.** Secado (#D6BE6E) se distingue poco sobre la superficie clara. La barra de aviso se oscurece o lleva borde, con un contraste de 3:1 o más frente a su fondo (RF-17b, CA-8b).
- D-5. **Build sin CDN de Flutter.** Se acepta el flag `--no-web-resources-cdn` en `web/brewtrack-web.Containerfile`, como recomienda QA. Hace falta para que CanvasKit salga de nginx y se cumplan RF-14 y CA-16. Seguridad lo revisó y no cambia nada de la spec 004.
- D-6. **Coma decimal.** El usuario decidió el 2026-10-15 usar coma decimal en toda la interfaz (RF-14b, CA-9b). Resuelve el choque entre CA-9 (`15,0 %`) y el test previo que exigía `15.0 %`.

## Preguntas abiertas

Ninguna.

## Historial

| Fecha | Versión | Cambio |
|---|---|---|
| 2026-10-15 | 0.1 | Borrador inicial a partir de la maqueta HTML y los requisitos acordados con el usuario. Pendiente de revisión. |
| 2026-10-15 | 1.0 | El usuario responde P-1 a P-4, que pasan a "Decisiones" (D-1 a D-4). RF-5 y CA-5 fijan negro o blanco puro en el encabezado. Nuevos RF-17b y CA-8b: la barra de aviso tiene un contraste de 3:1 o más frente a su fondo. El usuario aprueba la spec. |
| 2026-10-15 | 1.1 | Cambios que pide `qa-report.md`. El usuario decide la coma decimal (D-6): nuevos RF-14b y CA-9b; RF-32 ya no exige que pase el test previo con `15.0 %`, que se actualiza a la coma. RF-14 y CA-16 piden que CanvasKit también salga del contenedor `web`; se acepta `--no-web-resources-cdn` (D-5). Sigue aprobada. |
| 2026-10-15 | 1.2 | Spec aceptada según los informes de QA (aprobado en la segunda ronda, CA-1 a CA-21 y CA-9b pasan) y de seguridad (aprobado, sin bloqueantes). Seguridad no volvió a correr tras los últimos arreglos (familia `Roboto` apuntando a Public Sans, `›` en lugar de `→`, borde del punto del chip). Esos arreglos no tocan nginx, dependencias ni secretos, y CA-16 confirma cero peticiones externas. Límites que se aceptan: el coordinador hizo las pruebas de navegador, CA-17 se vio solo en "Entrar" y en la tabla de tuestes, y CA-20 no se comparó byte a byte. Quedan para specs futuras: el logo con fondo opaco en tema oscuro, la sesión con refresh token de un usuario que ya no existe, y las cabeceras de seguridad de nginx (hallazgo 7 de la auditoría). |
