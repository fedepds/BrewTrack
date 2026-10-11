# 001 — Resumen mensual

Estado: aprobada
Fecha: 2026-10-11

## Contexto y objetivo

El taller quiere ver su estado de un vistazo: cuánto café verde le queda y qué pasó en un mes. Hoy esa información está repartida entre las pantallas de lotes y de tuestes, y hay que sumarla a mano.

El usuario eligió un resumen general con cinco cifras. Descartó "planificar compras" y "medir producción".

Objetivo: una pantalla "Resumen" que muestre, para un mes elegido, lo recibido, lo tostado y la merma, junto con el stock de hoy.

## Historias de usuario

- HU-1. Como `roaster`, quiero ver cuántos kg de verde quedan hoy y en cuántos lotes, para saber con qué puedo tostar.
- HU-2. Como `roaster`, quiero ver cuánto tostamos en un mes y con qué merma, para saber cómo trabajamos.
- HU-3. Como `admin`, quiero ver cuánto café recibimos y tostamos en un mes, para seguir la marcha del taller.
- HU-4. Como `roaster` o `admin`, quiero pasar de un mes a otro, para revisar meses anteriores.

## Requisitos funcionales

### Cifras

- RF-1. **Lotes con stock:** cantidad de lotes con stock calculado mayor que 0. Refleja el día de hoy y no depende del mes elegido.
- RF-2. **Stock total de verde (kg):** suma del stock calculado de todos los lotes. Refleja el día de hoy y no depende del mes elegido.
- RF-3. El stock de cada lote es `received_kg` menos la suma de `green_in_kg` de sus tuestes, como manda la constitución. El sistema no lo guarda: lo calcula en cada consulta. Un lote con fecha de recepción posterior a hoy también cuenta en RF-1 y RF-2, igual que en el listado de lotes.
- RF-4. **Recibido en el mes:** cantidad de lotes y suma de `received_kg` de los lotes cuya fecha de recepción cae en el mes. La fecha de recepción es solo una fecha, sin hora.
- RF-5. **Tostado en el mes:** cantidad de tuestes, suma de `green_in_kg` y suma de `roasted_out_kg` de los tuestes cuya fecha de tueste cae en el mes.
- RF-6. **Merma media del mes:** `(1 − kg tostado ÷ kg verde) × 100`, con los totales de RF-5, redondeada a 2 decimales con la mitad hacia arriba (`12.345` → `12.35`). No es el promedio de la merma de cada tueste: así un tueste chico no pesa igual que uno grande.
- RF-7. Si el mes no tiene tuestes, la merma media es nula.

### Mes y zona horaria

- RF-8. El taller tiene una zona horaria. Se configura con la variable de entorno `TIMEZONE`. Si falta, vale `America/Argentina/Buenos_Aires`.
- RF-9. Un mes va desde el día 1 a las 00:00 hasta el día 1 del mes siguiente a las 00:00, sin incluirlo, en la zona horaria del taller.
- RF-10. El "mes actual" es el mes en curso en la zona horaria del taller, no en la del navegador.

### API

- RF-11. Endpoint: `GET /api/v1/stats/summary?month=YYYY-MM`.
- RF-12. Requiere sesión. Lo pueden usar los roles `roaster` y `admin`. La API impone el permiso.
- RF-13. `month` es opcional. Si falta, la API usa el mes actual (RF-10).
- RF-14. Si `month` no tiene el formato `YYYY-MM` o no es un mes válido (por ejemplo `2026-13` u `octubre`), la API responde 422 con el formato `{"error": {"code", "message"}}`.
- RF-15. Un mes sin datos, pasado o futuro, responde 200 con ceros en recibido y tostado, y `loss_pct: null`. Nunca responde 404 por falta de datos.
- RF-16. La respuesta tiene esta forma. Los kg van como texto con 3 decimales; `loss_pct` va como texto con 2 decimales o `null`:

```json
{
  "month": "2026-10",
  "lots_in_stock": 7,
  "stock_kg": "412.500",
  "received": {"lots": 2, "kg": "120.000"},
  "roasted": {"roasts": 18, "green_kg": "95.000", "roasted_kg": "80.750"},
  "loss_pct": "15.00"
}
```

- RF-17. Sin token o con un token inválido, la API responde 401 con el formato `{"error": {"code", "message"}}`.

### Pantalla "Resumen"

- RF-18. La navegación muestra "Resumen" a los dos roles, entre "Tuestes" y "Usuarios". La pantalla de inicio sigue siendo la de lotes.
- RF-19. Al entrar, la pantalla muestra el mes actual del taller (RF-10).
- RF-20. Un selector muestra el mes en español, con el nombre del mes en minúscula y el año, por ejemplo "octubre 2026".
- RF-21. El selector tiene una flecha "anterior" y una flecha "siguiente". Cada una cambia al mes contiguo y vuelve a cargar las cifras. La flecha "siguiente" está desactivada en el mes actual. La flecha "anterior" no tiene límite.
- RF-22. La pantalla muestra las cinco cifras de RF-1, RF-2, RF-4, RF-5 y RF-6. Las cifras de RF-1 y RF-2 indican que son de "hoy".
- RF-23. Los kg se muestran con 3 decimales y la unidad "kg" (por ejemplo "412.500 kg"). La merma se muestra con 2 decimales y "%" (por ejemplo "15.00 %").
- RF-24. Si la merma es nula, la pantalla muestra "—".
- RF-25. Si la API responde con error, la pantalla muestra el mensaje que devuelve el backend.

## Criterios de aceptación

### API

- CA-1. Dado un cliente sin token, cuando pide `GET /api/v1/stats/summary`, entonces recibe 401 y un cuerpo `{"error": {"code", "message"}}`.
- CA-2. Dado un usuario `roaster` con sesión, cuando pide `GET /api/v1/stats/summary`, entonces recibe 200 y un cuerpo con las claves `month`, `lots_in_stock`, `stock_kg`, `received`, `roasted` y `loss_pct`.
- CA-3. Dado un usuario `admin` con sesión, cuando pide `GET /api/v1/stats/summary`, entonces recibe 200 con las mismas claves de CA-2.
- CA-4. Dado un usuario con sesión, cuando pide `month=2026-13`, entonces recibe 422 y un cuerpo `{"error": {"code", "message"}}`.
- CA-5. Dado un usuario con sesión, cuando pide `month=octubre`, entonces recibe 422 y un cuerpo `{"error": {"code", "message"}}`.
- CA-6. Dados un lote recibido el 2026-09-30 con 50 kg y dos lotes recibidos el 2026-10-01 y el 2026-10-31 con 60 kg cada uno, cuando se pide `month=2026-10`, entonces `received` vale `{"lots": 2, "kg": "120.000"}`.
- CA-7. Dados dos tuestes en octubre de 2026 (10 kg verde → 8.500 kg tostado, y 5 kg → 4.000 kg) y uno en septiembre de 2026 (20 kg → 17 kg), cuando se pide `month=2026-10`, entonces `roasted` vale `{"roasts": 2, "green_kg": "15.000", "roasted_kg": "12.500"}`.
- CA-8. Dados en un mes un tueste de 1 kg verde → 0.500 kg tostado (merma 50 %) y otro de 19 kg → 17.100 kg (merma 10 %), cuando se pide ese mes, entonces `loss_pct` vale `"12.00"` y no `"30.00"`, que sería el promedio de las dos mermas.
- CA-9. Dado un lote de 30 kg con tuestes que suman 30 kg de verde, y otro lote de 20 kg con un tueste de 5 kg, cuando se pide el resumen, entonces `lots_in_stock` vale 1 y `stock_kg` vale `"15.000"`.
- CA-10. Dados varios lotes con y sin tuestes, cuando se pide el resumen y el listado de lotes, entonces `stock_kg` es igual a la suma del stock de todos los lotes del listado.
- CA-11. Dados `TIMEZONE=America/Argentina/Buenos_Aires` y un tueste del 31-10-2026 a las 22:00 hora de Buenos Aires (01-11-2026 01:00 UTC), cuando se pide `month=2026-10`, entonces el tueste cuenta en `roasted`; y cuando se pide `month=2026-11`, entonces no cuenta.
- CA-12. Dados `TIMEZONE=America/Argentina/Buenos_Aires` y un tueste del 01-10-2026 a las 00:00 hora de Buenos Aires, cuando se pide `month=2026-10`, entonces el tueste cuenta; y cuando se pide `month=2026-09`, entonces no cuenta.
- CA-13. Dado un mes sin lotes recibidos ni tuestes (por ejemplo `month=2020-01`), cuando se pide, entonces la respuesta es 200 con `received` igual a `{"lots": 0, "kg": "0.000"}`, `roasted` igual a `{"roasts": 0, "green_kg": "0.000", "roasted_kg": "0.000"}` y `loss_pct` igual a `null`.
- CA-14. Dado un mes futuro (por ejemplo `month=2099-01`), cuando se pide, entonces la respuesta es 200 con los mismos ceros y `null` de CA-13.
- CA-15. Dado un usuario con sesión, cuando pide el resumen sin `month`, entonces recibe 200 y `month` vale el mes actual en la zona horaria del taller.
- CA-16. Dada `TIMEZONE` sin definir, cuando se pide el resumen sin `month`, entonces `month` vale el mes actual en `America/Argentina/Buenos_Aires`.
- CA-17. Dada cualquier respuesta 200, entonces `stock_kg`, `received.kg`, `roasted.green_kg` y `roasted.roasted_kg` tienen exactamente 3 decimales, y `loss_pct` tiene exactamente 2 decimales o es `null`.

### Pantalla

- CA-18. Dada una respuesta con los datos del ejemplo de RF-16, cuando se muestra la pantalla, entonces aparecen "7", "412.500 kg", "2", "120.000 kg", "18", "95.000 kg", "80.750 kg" y "15.00 %".
- CA-19. Dada la pantalla abierta, entonces las cifras de lotes con stock y stock total incluyen el texto "hoy".
- CA-20. Dada una respuesta con `loss_pct: null`, cuando se muestra la pantalla, entonces la merma muestra "—".
- CA-21. Dado que el mes actual es octubre de 2026, cuando se abre la pantalla, entonces el selector muestra "octubre 2026" y la flecha "siguiente" está desactivada.
- CA-22. Dada la pantalla en "octubre 2026", cuando el usuario pulsa la flecha "anterior", entonces el selector muestra "septiembre 2026", la pantalla pide `month=2026-09` y la flecha "siguiente" queda activa.
- CA-23. Dada la pantalla en "septiembre 2026", cuando el usuario pulsa la flecha "siguiente", entonces el selector muestra "octubre 2026" y la flecha "siguiente" queda desactivada.
- CA-24. Dado un usuario `roaster`, cuando ve la navegación, entonces aparece "Resumen" después de "Tuestes".
- CA-25. Dado un usuario `admin`, cuando ve la navegación, entonces aparece "Resumen" entre "Tuestes" y "Usuarios".
- CA-26. Dado cualquier rol, cuando inicia sesión, entonces la primera pantalla es la de lotes, no el resumen.

## Chequeo de constitución

- **Alcance:** aplica. Solo resume lotes verdes y tuestes de un taller con datos que ya existen. No usa curvas, empaque, venta, recetas, cata ni multi-empresa.
- **Stock calculado:** aplica. RF-1, RF-2 y RF-3 calculan el stock en cada consulta como `received_kg` menos la suma de `green_in_kg`. Nada se guarda. CA-10 verifica que coincide con el listado de lotes.
- **Permisos en la API:** aplica. La API exige sesión y permite los dos roles (RF-12, CA-1 a CA-3). El frontend solo decide dónde aparece "Resumen" en la navegación.
- **Formato de error:** aplica. 401 y 422 responden `{"error": {"code", "message"}}` (RF-14, RF-17, CA-1, CA-4, CA-5). No hay 404 por falta de datos (RF-15).
- **Migraciones:** no aplica. La funcionalidad no cambia el esquema.
- **Secretos:** aplica en parte. `TIMEZONE` entra por variable de entorno, como toda configuración, pero no es un secreto. No se lee ni se imprime `.env`.

## Fuera de alcance

- Gráficos y series de varios meses.
- Desglose por nivel de tueste o por país.
- Exportar a CSV o PDF.
- Guardar el mes elegido en la URL.
- Comparar un mes con otro.

## Preguntas abiertas

Ninguna. El usuario resolvió las tres preguntas de la versión 1.0:

1. Resuelta. La flecha "anterior" no tiene límite en v1 (RF-21).
2. Resuelta. La merma se redondea con la mitad hacia arriba (RF-6).
3. Resuelta. Un lote con fecha de recepción futura cuenta en el stock de hoy (RF-3).

## Historial

| Fecha | Versión | Cambio |
|---|---|---|
| 2026-10-11 | 1.0 | Versión inicial. Diseño aprobado por el usuario en sesión de brainstorming. |
| 2026-10-11 | 1.1 | Spec aprobada. Se pasan a RF-3, RF-6 y RF-21 las respuestas del usuario a las tres preguntas abiertas. |
