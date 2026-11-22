# Baja la CLI de Snyk (binario único) y deja su ruta en $SNYK. Se usa con "." desde el Jenkinsfile.
# Necesita SNYK_TOKEN en el entorno; SNYK_CLI_VERSION es "stable" o una versión como "v1.1300.0".
: "${SNYK_TOKEN:?falta la credencial snyk-token en Jenkins}"
case "$(uname -m)" in
  x86_64) _bin=snyk-linux ;;
  aarch64|arm64) _bin=snyk-linux-arm64 ;;
  *) echo "arquitectura no soportada: $(uname -m)" >&2; return 1 ;;
esac
SNYK=/tmp/snyk
if [ ! -x "$SNYK" ]; then
  python3 -c 'import sys, urllib.request; urllib.request.urlretrieve(sys.argv[1], sys.argv[2])' \
    "https://downloads.snyk.io/cli/${SNYK_CLI_VERSION:-stable}/${_bin}" "$SNYK"
  chmod +x "$SNYK"
fi
"$SNYK" --version
export SNYK
