# Falco: seguridad en tiempo de ejecución

Kyverno revisa lo que entra al clúster. Falco mira lo que pasa después: lee las llamadas al sistema de cada contenedor y avisa cuando un proceso hace algo que no debería.

## Instalación

```sh
bash scripts/falco-up.sh
```

- Chart oficial `falcosecurity/falco` 9.2.2 (Falco 0.45.2), en el namespace `falco`. Valores en `falco/values.yaml`.
- Driver `modern_ebpf`: una sonda eBPF que no compila ni carga un módulo en el kernel. Pide kernel 5.8 o más con BTF, y la VM de Colima lo trae. Si el pod no arranca, probar `driver.kind=auto`.
- Alertas en JSON, una por línea, desde prioridad `notice`, con las reglas estables (`falco_rules.yaml`).
- Falco corre privilegiado para leer el kernel del nodo. Por eso el namespace `falco` queda fuera de las políticas de Kyverno.

## Evento detectado

```sh
bash scripts/falco-event.sh     # escribe reports/falco-event.log
```

**Escenario.** Alguien consiguió ejecutar comandos dentro del contenedor de la API, por ejemplo con una dependencia vulnerable. Desde ahí busca llaves SSH y credenciales de AWS para saltar a otros sistemas. MITRE ATT&CK llama a esto *acceso a credenciales* (T1552). El script lo simula con tres comandos que corren `find` y `grep` directamente, sin abrir ningún shell:

| Comando dentro del pod `api` | Regla de Falco | Prioridad |
|---|---|---|
| `find / -xdev -name id_rsa` | Search Private Keys or Passwords | WARNING |
| `grep -rl "BEGIN RSA PRIVATE" /etc /srv` | Search Private Keys or Passwords | WARNING |
| `find / -xdev -path "*/.aws/credentials"` | Find AWS Credentials | WARNING |

**Por qué es sospechoso.** La API solo corre `uvicorn`. Nunca lanza `find` ni `grep`, y menos buscando nombres de llaves privadas. Falco no necesita que la búsqueda encuentre algo: alcanza con que el proceso arranque con esos argumentos. El usuario `app` (uid 1000) ni siquiera puede leer `/root`, pero el intento queda registrado igual.

**Qué guarda el informe.** `reports/falco-event.log` tiene el escenario, los comandos que se ejecutaron con su salida, las alertas en JSON tal como las escribe Falco y un resumen con la hora, la regla, el pod, el usuario y el comando de cada una.

**Qué haría el equipo con esta alerta.** Revisar el pod (`kubectl -n brewtrack describe pod <pod>`), borrarlo para que Kubernetes cree uno limpio y buscar en los logs de la API cómo entró el atacante. Para que alguien vea la alerta en el momento, el siguiente paso sería enviarla a Slack o a un correo con Falcosidekick.

## Ver las alertas a mano

```sh
kubectl -n falco logs ds/falco -c falco -f | grep '"priority":"Warning"'
```
