# Plan — 007 Imágenes con versiones fijas y análisis con SlimToolkit

## Diseño
1. Fijar la etiqueta de cada `FROM` y de cada imagen del `Jenkinsfile` (RF-1 a RF-5).
2. Probar sin `apt-get upgrade` y `apk upgrade`; mantenerlos si Trivy falla (RF-12).
3. `scripts/slim-analysis.sh`: Docker 27 temporal, `slim xray` por imagen, informe Markdown, falla si falta un dato, `trap` borra el Docker temporal (RF-13 a RF-16).
4. Etapa "SlimToolkit imágenes" en el `Jenkinsfile`, entre "Trivy imágenes" y "Deploy minikube", con `archiveArtifacts`.
5. Actualizar `reports/` y la línea CI/CD de `AGENTS.md` (RF-17 a RF-19).

No hay cambios de API, pantallas, datos ni puertos.

## Constitución
| Regla | Cómo la cumple |
|---|---|
| Alcance | Sin funciones nuevas. Etiquetas exactas y Jenkins local entran por la constitución enmendada. |
| Stock calculado | No toca cálculos. |
| Permisos en la API | Sin endpoints nuevos. |
| Errores | Sin respuestas nuevas. |
| Esquema | Sin migraciones. |
| Secretos | El script no lee `.env` ni pasa variables de entorno de la app a Slim. El informe no trae variables de entorno de las imágenes. |
