"""Resume un informe JSON de `slim xray`: tamaño total y una línea por capa.
Uso: python -I -c "$(cat ci/slimtoolkit-summary.py)" [imagen_base instrucciones_de_la_base] < informe.json
El JSON no separa las capas heredadas: las instrucciones de la base son las primeras N."""
import json
import sys


def human(n: int) -> str:
    return f"{n / 1e6:.1f} MB"


report = json.load(sys.stdin)
top = report["image_stack"][-1]
base_name = sys.argv[1] if len(sys.argv) > 1 else ""
base_n = int(sys.argv[2]) if len(sys.argv) > 2 else 0

layers = {l["index"]: l for l in report["image_layers"]}
total = sum(i["size"] for i in top["instructions"])
print(top["full_name"])
print(f"tamaño total (suma de capas): {human(total)} ({total} bytes)")
if base_name:
    print(f"imagen base: {base_name} ({base_n} instrucciones heredadas)")
print()
print(f"{'origen':8} {'capa':>4} {'tamaño':>9}  {'agrega/cambia/borra':>19}  instrucción")
for n, ins in enumerate(top["instructions"]):
    if ins["size"] == 0:
        continue  # ENV, CMD y similares no pesan
    ch = layers.get(ins.get("layer_index"), {}).get("changes", {})
    cambios = f"{ch.get('added', 0)}/{ch.get('modified', 0)}/{ch.get('deleted', 0)}"
    origen = "base" if n < base_n else "nuestra"
    cmd = " ".join(ins["command_snippet"].split())[:90]
    print(f"{origen:8} {ins.get('layer_index', '-'):>4} {human(ins['size']):>9}  {cambios:>19}  {cmd}")
