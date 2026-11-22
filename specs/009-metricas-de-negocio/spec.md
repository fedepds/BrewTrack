# 009 — Métricas de negocio y dashboard de monitoreo

Estado: propuesta (falta aprobación del product-owner)
Fecha: 2026-11-22

## Contexto y objetivo

El Laboratorio 4 pide un dashboard de Grafana con pedidos por segundo, latencia promedio, CPU y memoria por pod, y al menos una métrica de negocio. La API ya publica métricas HTTP en `/metrics` (prometheus-fastapi-instrumentator), pero ninguna dice nada del taller. Prometheus tampoco lee CPU ni memoria.

Objetivo: la API publica en `/metrics` el stock de café verde y los tuestes que registra. Prometheus lee además CPU y memoria de cada pod. El dashboard de `grafana/dashboard.json` muestra todo.

## Decisiones

- D-1. El stock verde se publica como gauge que la API **calcula en cada scrape** con una consulta a la base. No se guarda en ninguna tabla, así que respeta la regla de stock de la constitución. Prometheus guarda la serie en el tiempo, como guarda cualquier otra métrica.
- D-2. Los tuestes se cuentan con contadores que suben al crear un tueste. Vuelven a cero cuando el pod se reinicia; `rate()` e `increase()` de Prometheus lo toleran. Editar o borrar un tueste no cambia los contadores.
- D-3. Si la base no responde, `/metrics` sigue devolviendo las métricas HTTP y omite las de negocio. Un fallo de la base no debe romper el monitoreo.
- D-4. El dashboard vive en `grafana/dashboard.json`, fuera del YAML de Kubernetes, para que haya una sola copia.

## Requisitos funcionales

- RF-1. `brewtrack_green_stock_kg` (gauge): suma de `received_kg` de todos los lotes menos la suma de `green_in_kg` de todos los tuestes.
- RF-2. `brewtrack_green_lots_with_stock` (gauge): cantidad de lotes con stock verde mayor a cero.
- RF-3. `brewtrack_roasts_created_total{roast_level}` (contador): sube en 1 por cada tueste creado con éxito (201).
- RF-4. `brewtrack_roast_green_in_kg_total` y `brewtrack_roast_out_kg_total` (contadores): suben con los kg de entrada y salida de cada tueste creado. Su cociente da la merma.
- RF-5. Un tueste rechazado (409, 422, 404) no mueve ningún contador.
- RF-6. El dashboard muestra, como mínimo: pedidos por segundo, latencia promedio, CPU por pod, memoria por pod, stock verde, tuestes y merma.
- RF-7. Los pedidos de Prometheus a `/metrics` no cuentan en los pedidos por segundo ni en la latencia.

## Fuera de alcance

- Stock tostado (spec 007): se suma al dashboard cuando la 007 esté implementada.
- Alertas de Prometheus o de Grafana.

## Criterios de aceptación

- CA-1. `pytest` cubre RF-1 a RF-5 (`api/tests/test_metrics.py`).
- CA-2. Con `scripts/load.sh` corriendo, todos los paneles del dashboard muestran datos.
- CA-3. En Prometheus, `/targets` muestra `api` y `kubernetes-cadvisor` en estado UP.
