# SlimToolkit: dockerd desechable con `--privileged`

Fecha: 2026-11-23. Spec 010.

## Qué cambió

`ci/slimtoolkit.sh` levanta un contenedor `docker:29.10.0-dind` con `--privileged`, instala dentro el binario oficial de slim 1.40.11 y corre ahí `xray` y `build`. El contenedor vive lo que dura el script y se borra al salir (`trap` y `post always` del Jenkinsfile).

## Por qué

slim 1.40.11 no exporta imágenes del almacén containerd del Docker del host, y su sensor necesita `fanotify` en un contenedor propio. Un dockerd aparte con almacén clásico resuelve las dos cosas sin tocar el Docker del host.

## Riesgo aceptado

`--privileged` da al contenedor casi los mismos poderes que root en la máquina. Se acepta porque:

- Jenkins ya monta el socket de Docker del host, que da el mismo acceso. Este contenedor no suma poder nuevo.
- No publica puertos. Su API (2375, sin TLS) escucha solo dentro de su red, y solo la usa el propio script.
- Dura segundos o minutos y solo corre imágenes de BrewTrack. En CI solo analiza (`xray`); la imagen `web` reducida sale de una corrida a mano de `reduce`.

## Descarga del binario

El script baja `dist_linux.tar.gz` (amd64) o `dist_linux_arm64.tar.gz` (arm64) de las releases de SlimToolkit 1.40.11 y verifica un sha256 fijo en el script antes de extraerlo. Para subir de versión, cambia `SLIM_VERSION` y recalcula los dos hashes.
