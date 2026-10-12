# 002 — Lotes y tuestes de ejemplo al iniciar

Estado: aprobada
Fecha: 2026-10-12

## Contexto y objetivo

Hoy, al levantar BrewTrack sobre una base nueva, las pantallas de lotes, tuestes y resumen aparecen vacías. Para probar el sistema o mostrarlo hay que cargar datos a mano, uno por uno.

El usuario pidió que el stack arranque con unos 20 lotes de café verde ya cargados. Dejó a criterio del producto qué lotes cargar. Después pidió agregar también tuestes de ejemplo.

Objetivo: al levantar el stack con `podman compose up` sobre una base nueva, BrewTrack carga 20 lotes de ejemplo realistas. Cuando existe el primer usuario, carga 24 tuestes de ejemplo sobre esos lotes, para que el stock, la merma y el resumen mensual (spec 001) muestren datos. La carga nunca duplica datos ni toca datos reales.

## Historias de usuario

- HU-1. Como `admin`, quiero que una instalación nueva arranque con lotes y tuestes cargados, para mostrar el sistema sin preparar datos.
- HU-2. Como `roaster`, quiero ver lotes con stock desde el primer día, para probar el alta de tuestes.
- HU-3. Como `admin`, quiero ver el resumen mensual con cifras desde el primer día, para mostrar cómo se calcula la merma.
- HU-4. Como `admin`, quiero apagar la carga con una variable de entorno, para instalar el taller real sin datos de ejemplo.
- HU-5. Como `admin`, quiero distinguir un lote o un tueste de ejemplo de uno real, para borrarlos cuando ya no sirvan.

## Requisitos funcionales

### Interruptor

- RF-1. La variable de entorno `SEED_DEMO_LOTS` enciende o apaga toda la carga de ejemplo: lotes y tuestes.
- RF-2. Con `podman compose up`, si `SEED_DEMO_LOTS` no está definida, vale `true`. Fuera de compose (API en desarrollo con `uvicorn`, pruebas), si la variable no está definida, la carga no ocurre.
- RF-3. `.env.example` documenta `SEED_DEMO_LOTS` con un comentario que explica que carga lotes y tuestes de ejemplo y cómo apagarla.

### Cuándo se cargan los lotes

- RF-4. La API carga los lotes de ejemplo al arrancar, después de aplicar las migraciones.
- RF-5. La carga de lotes ocurre solo si `SEED_DEMO_LOTS` vale `true` y la base no tiene ningún lote.
- RF-6. Si la base ya tiene al menos un lote, la API no carga lotes y no cambia ningún lote existente. Esto cubre los reinicios del contenedor y las bases con datos reales.
- RF-7. Si un admin borra todos los lotes y la API reinicia con la carga encendida, los 20 lotes vuelven. El usuario lo aceptó. Para evitarlo, se pone `SEED_DEMO_LOTS=false`.

### Cuándo se cargan los tuestes

Todo tueste necesita un autor, y una base nueva no tiene usuarios hasta que alguien ejecuta `create-admin`. Por eso los tuestes se cargan en dos momentos posibles.

- RF-8. La carga de tuestes se intenta:
  - al arrancar la API, justo después del paso de lotes (RF-4);
  - al terminar `create-admin`, después de crear el usuario.
- RF-9. La carga de tuestes ocurre solo si se cumplen todas estas condiciones:
  - `SEED_DEMO_LOTS` vale `true`;
  - la base no tiene ningún tueste;
  - la base tiene al menos un usuario activo;
  - existen los 13 lotes que usan los tuestes de RF-17, con su `code` y con la nota de RF-14;
  - cada tueste cabe en el stock de su lote, con la misma regla que `POST /api/v1/roasts`.
- RF-10. El autor de todos los tuestes de ejemplo es el usuario activo más antiguo. En una base nueva es el primer admin.
- RF-11. La carga no crea usuarios ni contraseñas.
- RF-12. Si la base ya tiene al menos un tueste, la API no carga tuestes y no cambia ningún tueste existente. Si un admin borra todos los tuestes y la API reinicia con la carga encendida y los lotes de ejemplo todavía existen, los 24 tuestes vuelven, igual que los lotes en RF-7. Para evitarlo, se pone `SEED_DEMO_LOTS=false`.

### Resultado y fallos

- RF-13. La carga de lotes y la de tuestes son todo o nada, cada una por su lado: o quedan los 20 lotes o ninguno; o quedan los 24 tuestes o ninguno. Si una carga falla, el error queda en el log y la API arranca igual. Si falla dentro de `create-admin`, el admin queda creado igual y el comando termina sin error.
- RF-14. Los 20 lotes llevan en `notes` el texto "Lote de ejemplo cargado al iniciar BrewTrack." Los 24 tuestes llevan en `notes` el texto "Tueste de ejemplo cargado al iniciar BrewTrack." Así se distinguen de los reales.
- RF-15. La API y `create-admin` escriben una línea con el resultado de cada carga:
  - "Se cargaron 20 lotes de ejemplo" o "Carga de lotes de ejemplo omitida: la base ya tiene lotes";
  - "Se cargaron 24 tuestes de ejemplo" u "Carga de tuestes de ejemplo omitida: " seguido del motivo: "la base ya tiene tuestes", "no hay usuarios activos", "faltan lotes de ejemplo" o "stock insuficiente";
  - "Carga de datos de ejemplo desactivada" si `SEED_DEMO_LOTS` no vale `true`.

  Ninguna línea muestra secretos ni el contenido de `.env`.
- RF-16. Cuando `/api/v1/health` responde sano por primera vez después de arrancar, las cargas de ese arranque ya terminaron.

### Qué se carga: lotes

- RF-17. La carga crea exactamente los 20 lotes de esta tabla, con esos valores. Cada lote cumple las mismas reglas que un lote creado con `POST /api/v1/green-lots`, y las restricciones de la base. El `code` sigue el patrón `GL-AAAA-NNN`, con el año de recepción y un número correlativo dentro de ese año. `harvest_year` nunca supera el año de recepción. Las fincas y los productores son verosímiles, no necesariamente reales.

| code | origin_country | region | farm | producer | variety | process | altitude_m | harvest_year | received_at | received_kg |
|---|---|---|---|---|---|---|---|---|---|---|
| GL-2025-001 | Brasil | Sul de Minas | Fazenda Santa Inês | Família Pereira | Yellow Bourbon | Natural | 1100 | 2025 | 2025-11-11 | 120.000 |
| GL-2025-002 | Brasil | Cerrado Mineiro | Fazenda Boa Vista | Família Costa | Mundo Novo | Despulpado natural | (vacío) | 2025 | 2025-11-11 | 180.000 |
| GL-2025-003 | Colombia | Huila | La Esperanza | Familia Rojas | Caturra | Lavado | 1750 | 2025 | 2025-12-02 | 70.000 |
| GL-2025-004 | Colombia | Nariño | El Mirador | Asociación de Productores de Buesaco | Castillo | Lavado | 2100 | 2025 | 2025-12-02 | 140.000 |
| GL-2026-001 | Colombia | Cauca | Las Brisas | Hernán Muñoz | Pink Bourbon | Honey | 1850 | 2025 | 2026-01-13 | 35.000 |
| GL-2026-002 | Bolivia | Caranavi | Finca Illimani | Familia Mamani | Java | Natural | 1650 | 2025 | 2026-02-17 | 69.000 |
| GL-2026-003 | Perú | Cajamarca | El Huabo | Cooperativa de San Ignacio | Bourbon, Typica | Lavado | 1800 | 2025 | 2026-02-17 | 69.000 |
| GL-2026-004 | Ruanda | Nyamasheke | Estación Muhondo | Cooperativa de Nyamasheke | Red Bourbon | Lavado | 1800 | 2025 | 2026-03-10 | 60.000 |
| GL-2026-005 | Guatemala | Huehuetenango | Finca Los Altos | Familia Villatoro | Bourbon, Caturra | Lavado | 1800 | 2026 | 2026-04-14 | 69.000 |
| GL-2026-006 | Guatemala | Antigua | Finca San Rafael | Familia Zelaya | Bourbon | Lavado | 1600 | 2026 | 2026-04-14 | 138.000 |
| GL-2026-007 | Honduras | Marcala | El Cedro | Cooperativa de Marcala | Catuaí | Lavado | 1500 | 2026 | 2026-04-28 | 69.000 |
| GL-2026-008 | El Salvador | Santa Ana | Finca Los Naranjos | Familia Aguilar | Pacamara | Honey | 1650 | 2026 | 2026-04-28 | 34.500 |
| GL-2026-009 | Costa Rica | Tarrazú | Finca El Llano | Familia Solís | Caturra, Catuaí | Honey | 1700 | 2026 | 2026-05-12 | 69.000 |
| GL-2026-010 | Costa Rica | Valle Occidental | Finca Alto Naranjo | Familia Vargas | Villa Sarchí | Natural | 1500 | 2026 | 2026-05-12 | 34.500 |
| GL-2026-011 | Etiopía | Yirgacheffe | Estación Konga | Cooperativa Konga | Heirloom etíope | Lavado | 2000 | 2026 | 2026-05-26 | 60.000 |
| GL-2026-012 | Etiopía | Guji | Estación Hambela | Productores de Hambela | Heirloom etíope | Natural | 2150 | 2026 | 2026-05-26 | 120.000 |
| GL-2026-013 | Panamá | Boquete | Finca Las Nubes | Familia Serracín | Geisha | Lavado | 1700 | 2026 | 2026-06-09 | 15.000 |
| GL-2026-014 | Panamá | Volcán | Finca Cerro Punta | Familia Araúz | Catuaí | Natural | 1500 | 2026 | 2026-06-09 | 30.000 |
| GL-2026-015 | Kenia | Nyeri | Gaturiri | Cooperativa de Gaturiri | SL28, SL34 | Lavado | 1750 | 2025 | 2026-07-07 | 60.000 |
| GL-2026-016 | Indonesia | Aceh (Gayo) | Lago Tawar | Cooperativa Gayo | Ateng, Tim Tim | Semilavado | 1500 | 2026 | 2026-08-04 | 60.000 |

Totales de control: 20 lotes, 13 países, 5 procesos (Lavado, Natural, Honey, Despulpado natural, Semilavado), 1 lote sin altitud, 1502.000 kg recibidos.

### Qué se carga: tuestes

- RF-18. La carga crea exactamente los 24 tuestes de esta tabla, con esos valores. Las horas van en la zona `America/Argentina/Buenos_Aires` (UTC−3); son instantes fijos y no cambian con `TIMEZONE`. La merma (`loss_pct`) la calcula la API con la regla de siempre; la columna "merma" sirve de control.

| # | lote | roasted_at | green_in_kg | roasted_out_kg | merma | duration_s | drop_temp_c | roast_level |
|---|---|---|---|---|---|---|---|---|
| 1 | GL-2026-005 | 2026-06-03 09:00 | 12.000 | 10.200 | 15.00 | 660 | 207.5 | medium |
| 2 | GL-2026-009 | 2026-06-03 10:30 | 10.000 | 8.600 | 14.00 | 600 | 202.0 | light |
| 3 | GL-2026-011 | 2026-06-17 09:00 | 8.000 | 6.960 | 13.00 | 570 | 199.5 | light |
| 4 | GL-2025-001 | 2026-06-17 10:30 | 15.000 | 12.600 | 16.00 | 720 | 212.0 | medium |
| 5 | GL-2026-013 | 2026-07-01 09:00 | 5.000 | 4.350 | 13.00 | 540 | 198.0 | light |
| 6 | GL-2025-002 | 2026-07-01 10:30 | 15.000 | 12.450 | 17.00 | 780 | 222.0 | dark |
| 7 | GL-2026-006 | 2026-07-15 09:00 | 12.000 | 10.140 | 15.50 | 660 | 208.0 | medium |
| 8 | GL-2026-015 | 2026-07-15 10:30 | 10.000 | 8.650 | 13.50 | 600 | 201.5 | light |
| 9 | GL-2025-004 | 2026-07-29 09:00 | 12.000 | 10.200 | 15.00 | 650 | 206.0 | medium |
| 10 | GL-2026-012 | 2026-08-05 09:00 | 10.000 | 8.500 | 15.00 | 590 | 200.0 | light |
| 11 | GL-2025-001 | 2026-08-05 10:30 | 15.000 | 12.600 | 16.00 | 720 | 213.0 | medium |
| 12 | GL-2026-016 | 2026-08-19 09:00 | 10.000 | 8.300 | 17.00 | 750 | 220.5 | dark |
| 13 | GL-2026-013 | 2026-08-19 10:30 | 5.000 | 4.375 | 12.50 | 540 | 198.5 | light |
| 14 | GL-2026-008 | 2026-08-26 09:00 | 8.000 | 6.840 | 14.50 | 610 | 204.0 | medium |
| 15 | GL-2026-005 | 2026-09-02 09:00 | 12.000 | 10.140 | 15.50 | 660 | 208.0 | medium |
| 16 | GL-2025-002 | 2026-09-02 10:30 | 15.000 | 12.375 | 17.50 | 790 | 223.0 | dark |
| 17 | GL-2026-011 | 2026-09-16 09:00 | 8.000 | 6.960 | 13.00 | 570 | 200.0 | light |
| 18 | GL-2026-013 | 2026-09-16 10:30 | 5.000 | 4.350 | 13.00 | 540 | 198.0 | light |
| 19 | GL-2026-003 | 2026-09-30 09:00 | 12.000 | 10.200 | 15.00 | 650 | 209.0 | medium |
| 20 | GL-2026-009 | 2026-10-01 09:00 | 10.000 | 8.600 | 14.00 | 600 | 202.5 | light |
| 21 | GL-2025-001 | 2026-10-01 10:30 | 15.000 | 12.600 | 16.00 | 720 | 212.5 | medium |
| 22 | GL-2026-012 | 2026-10-07 09:00 | 10.000 | 8.500 | 15.00 | 590 | 200.5 | light |
| 23 | GL-2026-016 | 2026-10-07 10:30 | 10.000 | 8.250 | 17.50 | 760 | 221.0 | dark |
| 24 | GL-2026-006 | 2026-10-09 09:00 | 12.000 | 10.200 | 15.00 | 650 | 207.0 | medium |

- RF-19. Reglas que cumple la tabla:
  - cada tueste cumple las reglas de `POST /api/v1/roasts` y las restricciones de la base (`roasted_out_kg <= green_in_kg`, pesos y tiempos mayores que 0);
  - cada tueste es posterior a la fecha de recepción de su lote;
  - ningún lote queda con stock negativo. `GL-2026-013` queda en 0 kg, para mostrar un lote agotado;
  - hay tuestes en cada mes de junio a octubre de 2026, y en los tres niveles.

Totales de control:

| Cifra | Valor |
|---|---|
| Tuestes | 24 (10 light, 10 medium, 4 dark) |
| Verde tostado | 256.000 kg |
| Stock total después de cargar los tuestes | 1246.000 kg |
| Lotes con stock mayor que 0 | 19 |
| Octubre de 2026 | 5 tuestes, 57.000 kg verde, 48.150 kg tostado, merma media 15.53 |
| Septiembre de 2026 | 5 tuestes, 52.000 kg verde, 44.025 kg tostado, merma media 15.34 |

Stock de cada lote con tuestes después de la carga:

| Lote | Stock (kg) |
|---|---|
| GL-2025-001 | 75.000 |
| GL-2025-002 | 150.000 |
| GL-2025-004 | 128.000 |
| GL-2026-003 | 57.000 |
| GL-2026-005 | 45.000 |
| GL-2026-006 | 114.000 |
| GL-2026-008 | 26.500 |
| GL-2026-009 | 49.000 |
| GL-2026-011 | 44.000 |
| GL-2026-012 | 100.000 |
| GL-2026-013 | 0.000 |
| GL-2026-015 | 50.000 |
| GL-2026-016 | 40.000 |

Los otros 7 lotes no tienen tuestes y su stock es igual a su `received_kg`.

- RF-20. Los lotes y tuestes de ejemplo se comportan como cualquier otro: se ven, se filtran, se editan y se borran con los endpoints y permisos que ya existen. El autor de RF-10 cuenta como autor de los tuestes de ejemplo para `PATCH /api/v1/roasts/{id}`.

## Criterios de aceptación

### Carga de lotes (pruebas de la API)

- CA-1. Dada una base sin lotes ni usuarios y `SEED_DEMO_LOTS=true`, cuando la API arranca, entonces la base tiene exactamente 20 lotes, sus `code` son los 20 de RF-17 y no tiene tuestes.
- CA-2. Dada la carga de CA-1, cuando se compara cada lote con su fila de RF-17, entonces todos los campos coinciden, `notes` vale "Lote de ejemplo cargado al iniciar BrewTrack." y la suma de `received_kg` vale `1502.000`.
- CA-3. Dada una base con los 20 lotes de ejemplo y `SEED_DEMO_LOTS=true`, cuando la API arranca otra vez, entonces la base sigue con 20 lotes, sin códigos repetidos, y cada lote conserva su `id` y su `updated_at`.
- CA-4. Dada una base con un solo lote real (`GL-2026-900`) y `SEED_DEMO_LOTS=true`, cuando la API arranca, entonces la base tiene solo ese lote y sus datos no cambian.
- CA-5. Dada una base sin lotes y `SEED_DEMO_LOTS=false`, cuando la API arranca, entonces la base sigue sin lotes.
- CA-6. Dada una base sin lotes y `SEED_DEMO_LOTS` sin definir, cuando la API arranca fuera de compose, entonces la base sigue sin lotes.
- CA-7. Dada una base sin lotes y un fallo provocado a mitad de la carga de lotes, cuando la API arranca, entonces la base sigue sin lotes, el log contiene el error y `/api/v1/health` responde 200.
- CA-8. Dados los 20 lotes de RF-17, cuando cada uno se valida con las reglas de `POST /api/v1/green-lots`, entonces los 20 pasan sin error.

### Carga de tuestes (pruebas de la API y de `create-admin`)

- CA-9. Dada la carga de CA-1 (sin usuarios) y `SEED_DEMO_LOTS=true`, cuando se ejecuta `create-admin`, entonces el admin queda creado, la base tiene los 24 tuestes de RF-18 y el autor de todos es ese admin.
- CA-10. Dada la carga de CA-9, cuando se compara cada tueste con su fila de RF-18, entonces `roasted_at`, `green_in_kg`, `roasted_out_kg`, `duration_s`, `drop_temp_c` y `roast_level` coinciden, `loss_pct` vale lo de la columna "merma" y `notes` vale "Tueste de ejemplo cargado al iniciar BrewTrack."
- CA-11. Dada una base con los 20 lotes de ejemplo, sin tuestes y con un usuario activo, y `SEED_DEMO_LOTS=true`, cuando la API arranca, entonces la base tiene los 24 tuestes.
- CA-12. Dada una base nueva con un usuario activo ya creado y `SEED_DEMO_LOTS=true`, cuando la API arranca, entonces quedan cargados en ese arranque los 20 lotes y los 24 tuestes.
- CA-13. Dada una base con los 20 lotes de ejemplo y sin usuarios, cuando la API arranca, entonces la base no tiene tuestes y el log muestra "Carga de tuestes de ejemplo omitida: no hay usuarios activos".
- CA-14. Dada la carga de CA-9, cuando la API arranca otra vez y cuando se ejecuta `create-admin` con otro email, entonces la base sigue con 24 tuestes y cada uno conserva su `id`, su autor y su `updated_at`.
- CA-15. Dada una base con los 20 lotes de ejemplo, un usuario activo y un tueste real, cuando la API arranca, entonces la base tiene solo ese tueste y sus datos no cambian.
- CA-16. Dada una base con los lotes de ejemplo menos `GL-2026-013`, un usuario activo y sin tuestes, cuando la API arranca, entonces la base no tiene tuestes y el log muestra "Carga de tuestes de ejemplo omitida: faltan lotes de ejemplo".
- CA-17. Dada una base con los 20 lotes de ejemplo, `GL-2026-013` editado a `received_kg` `10.000`, un usuario activo y sin tuestes, cuando la API arranca, entonces la base no tiene tuestes y el log muestra "Carga de tuestes de ejemplo omitida: stock insuficiente".
- CA-18. Dada una base con los 20 lotes de ejemplo, sin usuarios y `SEED_DEMO_LOTS=false`, cuando se ejecuta `create-admin`, entonces el admin queda creado y la base no tiene tuestes.
- CA-19. Dada una base con los 20 lotes de ejemplo, sin usuarios, y un fallo provocado a mitad de la carga de tuestes, cuando se ejecuta `create-admin`, entonces el admin queda creado, la base no tiene tuestes, la salida contiene el error y el comando termina con código 0.
- CA-20. Dados dos usuarios activos, creados en momentos distintos, una base con los 20 lotes de ejemplo y sin tuestes, cuando la API arranca, entonces el autor de los 24 tuestes es el usuario creado primero.
- CA-21. Dados los 24 tuestes de RF-18, cuando cada uno se valida con las reglas de `POST /api/v1/roasts`, entonces los 24 pasan sin error; y cada `roasted_at` es posterior a la fecha de recepción de su lote.
- CA-22. Dada la carga de CA-9, entonces la base tiene un solo usuario: el admin de `create-admin`.

### Datos visibles (pruebas de la API)

- CA-23. Dada la carga de CA-1 (sin tuestes) y un usuario `roaster` con sesión, cuando pide `GET /api/v1/green-lots?limit=50`, entonces recibe 200, 20 lotes, y el stock de cada uno es igual a su `received_kg`.
- CA-24. Dada la carga de CA-9 y un usuario `roaster` con sesión, cuando pide `GET /api/v1/green-lots?limit=50`, entonces el stock de cada lote coincide con la tabla de stock de RF-19 o con su `received_kg` si no tiene tuestes, y ningún stock es negativo.
- CA-25. Dada la carga de CA-9 y `TIMEZONE=America/Argentina/Buenos_Aires`, cuando un usuario pide `GET /api/v1/stats/summary?month=2026-10`, entonces `lots_in_stock` vale 19, `stock_kg` vale `"1246.000"`, `roasted` vale `{"roasts": 5, "green_kg": "57.000", "roasted_kg": "48.150"}` y `loss_pct` vale `"15.53"`.
- CA-26. Dada la carga de CA-9, cuando un usuario pide `GET /api/v1/stats/summary?month=2026-09`, entonces `roasted` vale `{"roasts": 5, "green_kg": "52.000", "roasted_kg": "44.025"}` y `loss_pct` vale `"15.34"`.
- CA-27. Dada la carga de CA-9, cuando un cliente sin token pide `GET /api/v1/green-lots` o `GET /api/v1/roasts`, entonces recibe 401 con el cuerpo `{"error": {"code", "message"}}`.
- CA-28. Dada la carga de CA-9 y un usuario `roaster`, cuando pide `DELETE` de un tueste de ejemplo, entonces recibe 403 con el cuerpo `{"error": {"code", "message"}}`. Dado el admin, cuando pide lo mismo, entonces recibe 204 y quedan 23 tuestes.
- CA-29. Dada la carga de CA-9 y un usuario `roaster` que no es el autor, cuando pide `PATCH` de un tueste de ejemplo, entonces recibe 403 con el cuerpo `{"error": {"code", "message"}}`.
- CA-30. Dada la carga de CA-9 y el admin, cuando pide `DELETE` de `GL-2026-013`, entonces recibe 409 con el cuerpo `{"error": {"code", "message"}}`, porque el lote tiene tuestes.
- CA-31. Dada la carga de CA-1, cuando un usuario pide `GET /api/v1/green-lots?country=Etiopía`, entonces recibe los 2 lotes de Etiopía.
- CA-32. Dados los casos de CA-1, CA-4, CA-5, CA-9, CA-13 y CA-15, entonces el log o la salida de `create-admin` muestran la línea de RF-15 que corresponde a cada caso.

### Stack completo (prueba manual de QA)

- CA-33. Dado un volumen `pgdata` nuevo y `.env` sin `SEED_DEMO_LOTS`, cuando se ejecuta `podman compose up --build -d`, se crea el primer admin y se entra en http://localhost:8080, entonces la pantalla de lotes muestra los 20 lotes, la de tuestes muestra 24 tuestes y el resumen de octubre de 2026 muestra 5 tuestes y merma "15.53 %".
- CA-34. Dado el stack de CA-33, cuando se ejecuta `podman compose restart api`, entonces siguen 20 lotes y 24 tuestes.
- CA-35. Dado el stack de CA-33 con un lote editado (por ejemplo, `received_kg` de `GL-2026-013` cambiado a `20.000`), cuando se reinicia `api`, entonces el lote conserva `20.000` y su stock es `5.000`.

## Chequeo de constitución

- **Alcance:** aplica. Solo carga lotes verdes y tuestes con datos resumen de un taller. No crea curvas, empaque, venta, recetas, cata ni datos de otra empresa.
- **Stock calculado:** aplica. La carga guarda `received_kg` y `green_in_kg`, como cualquier alta. No guarda stock. Cada tueste respeta el stock disponible de su lote (RF-9, RF-19). CA-24 y CA-25 verifican el stock calculado.
- **Permisos en la API:** aplica. No hay endpoints nuevos. Los datos de ejemplo usan los endpoints y permisos que ya existen (RF-20, CA-27 a CA-30). La carga corre dentro de la API al arrancar y dentro de `create-admin`, no la dispara ningún cliente.
- **Formato de error:** aplica. No hay respuestas nuevas. CA-27 a CA-30 verifican que 401, 403 y 409 siguen con `{"error": {"code", "message"}}`.
- **Migraciones:** no aplica. La funcionalidad no cambia el esquema. La carga no va dentro de una migración: las migraciones corren siempre, y RF-1 exige poder apagar la carga.
- **Secretos:** aplica. `SEED_DEMO_LOTS` entra por variable de entorno, pero no es un secreto. La carga no crea usuarios ni contraseñas (RF-11): el autor de los tuestes es un usuario que ya existe. RF-15 prohíbe que el log muestre secretos o el contenido de `.env`.

## Fuera de alcance

- Usuarios de ejemplo.
- Un botón o endpoint para cargar o borrar los datos de ejemplo.
- Borrar en bloque los datos de ejemplo.
- Fechas relativas al día de la instalación.
- Recordar que la carga ya ocurrió una vez (RF-7, RF-12).
- Cambios en la interfaz Flutter. Por eso esta spec no pide pruebas de widgets.

## Preguntas abiertas

Ninguna. El usuario resolvió las cuatro preguntas de la versión 1.0:

1. Resuelta. Se agregan tuestes de ejemplo en esta spec (RF-8 a RF-19).
2. Resuelta. Con compose, la carga está encendida por defecto (RF-2).
3. Resuelta. Una base vaciada a mano vuelve a recibir los lotes de ejemplo (RF-7). La misma regla se extiende a los tuestes (RF-12).
4. Resuelta. Las fechas son fijas (RF-17, RF-18).

## Historial

| Fecha | Versión | Cambio |
|---|---|---|
| 2026-10-12 | 1.0 | Versión inicial a partir del pedido del usuario: unos 20 lotes cargados al levantar el stack. |
| 2026-10-12 | 1.1 | Spec aprobada con las respuestas del usuario. Se agregan 24 tuestes de ejemplo. Como una base nueva no tiene usuarios, la carga de tuestes se intenta al arrancar la API y al terminar `create-admin`, y su autor es el usuario activo más antiguo. No se crean usuarios ni contraseñas. `SEED_DEMO_LOTS` pasa a controlar lotes y tuestes. La regla de base vaciada (RF-7) se extiende a los tuestes (RF-12). Los criterios se renumeran: los CA-9 a CA-17 de la 1.0 pasan a CA-23, CA-27, CA-28, CA-31, CA-32 y CA-33 a CA-35, con cambios para incluir los tuestes. |
