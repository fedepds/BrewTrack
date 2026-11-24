# Baja la CLI de Snyk (binario único) y deja su ruta en $SNYK. Se usa con "." desde el Jenkinsfile.
# Toma el token de SNYK_TOKEN (Jenkins) o, si falta, la sesión que guardó "snyk auth" en la máquina (una sola vez).
# SNYK_CLI_VERSION es "stable" o una versión como "v1.1300.0".
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) _bin=snyk-linux ;;
  Linux-aarch64|Linux-arm64) _bin=snyk-linux-arm64 ;;
  Darwin-x86_64) _bin=snyk-macos ;;
  Darwin-arm64) _bin=snyk-macos-arm64 ;;
  *) echo "sistema no soportado: $(uname -s) $(uname -m)" >&2; return 1 ;;
esac
# Nombre por binario: un /tmp/snyk de Linux no sirve en macOS y al revés.
SNYK=/tmp/$_bin
if [ ! -x "$SNYK" ]; then
  python3 -c 'import sys, urllib.request; urllib.request.urlretrieve(sys.argv[1], sys.argv[2])' \
    "https://downloads.snyk.io/cli/${SNYK_CLI_VERSION:-stable}/${_bin}" "$SNYK"
  chmod +x "$SNYK"
fi
"$SNYK" --version
export SNYK
