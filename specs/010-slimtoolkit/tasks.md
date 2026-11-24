# 010 — Tareas

1. [x] Script `ci/slimtoolkit.sh`, modo `xray` (historias 1-6, 9, 12, 23, 24).
2. [x] Resumen de texto `ci/slimtoolkit-summary.py` (historias 2-5, 9).
3. [x] Modo `reduce`: build, prueba HTTP, usuario, comparación (historias 14-17, 19; desde el cambio 1, solo a mano).
4. [x] `Jenkinsfile`: análisis en paralelo (10, 11), deploy intacto (22), limpieza. La reducción, su Trivy y la publicación (13, 18, 20, 21) salieron con el cambio 1.
5. [x] `.gitignore` de `reports/slimtoolkit/` (25). El archivado de `reports/**` ya lo cubre (7, 8).
6. [x] Prueba local de `xray` y de la lógica de `reduce` (ver dev-notes).
7. [x] `slim build` real en local. Corrida en Jenkins: pendiente (ver dev-notes).
8. [x] Cambio 1: quitar del `Jenkinsfile` `Reducir web`, `Trivy web reducida`, `WEB_CHECK_PATHS`, el push y el `rmi` de la `-slim`. Docs, README, `image-analysis.md` y plan al día.
