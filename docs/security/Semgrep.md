QUe hice en semgrep.
instale con brew install semgrep
luego importe y clone las reglas de la comunidad

git clone --depth 1 https://github.com/semgrep/semgrep-rules.git ~/semgrep-rules

Luego orri el analisis para mis librerias/lenguges y dependencias.
semgrep scan \
  --config ~/semgrep-rules/python \
  --config ~/semgrep-rules/dockerfile \
  --config ~/semgrep-rules/yaml \
  --config ~/semgrep-rules/generic/nginx \
  --config ~/semgrep-rules/generic/secrets \
  --metrics=off \
  --exclude .venv --exclude web/build --exclude .pubcache


Para el front ya que no hay reglas para dart
corri: flutter analyze
flutter pub outdated para visualizar las dependencias desactualizadas
flutter pub upgrade --major-versions resuelve las dependencias a las mayors
Tuve que aactualizar a Riverpod3 que me cambio algunas cosas en el codigo, como por ejemplo antes utilizaba valueOrNull y con la actualizacion esto quedaba deprecado y ahora con solamente poner value devuelve null mientras carga o si hay un error.