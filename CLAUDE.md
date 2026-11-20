# CLAUDE.md: reglas del proyecto Ansible-Azure-WebServer

Proyecto demostrativo **"Terraform aprovisiona, Ansible configura"** en Azure: Terraform crea una VM Linux con su red e IP pública y genera el inventario; Ansible instala nginx y publica una web estática; al terminar se destruye todo.

## Entorno de trabajo

- **Claude edita en Windows** (VS Code). **El usuario ejecuta todos los comandos** de `az`, `terraform`, `ansible` y `git` en **Ubuntu (WSL 2)** y pega la salida. Claude no ejecuta esas herramientas: entrega los comandos listos para copiar.
- El proyecto está en el disco de Windows; en WSL: `/mnt/c/Cloud-DevOps/Cloud-Data_Projects/Ansible-Azure-WebServer`.
- Recordar comprobar la terminal por el prompt: Ubuntu (`usuario@equipo`, rutas `/mnt/c/...`), no Git Bash (`MINGW64`, rutas `/c/...`).
- Particularidades de WSL, resueltas desde el diseño (no deshacerlas):
  - `ansible.cfg` se carga con `ANSIBLE_CONFIG` (ruta absoluta en `~/.bashrc`), porque Ansible ignora un `ansible.cfg` en un directorio *world-writable* como `/mnt/c`.
  - La clave SSH vive en `~/.ssh/lab_azure_ed25519` de WSL, nunca en `/mnt/c` (allí no se aplica `chmod 600`).
  - Finales de línea **LF** en todos los archivos (`.gitattributes` con `eol=lf`, `core.autocrlf false`).
  - Azure CLI de Linux (`which az` → `/usr/bin/az`) con `az login` dentro de WSL; `ARM_SUBSCRIPTION_ID` se calcula en `~/.bashrc`.

## Forma de trabajo

- Avanzar **fase por fase**. Antes de escribir cada archivo, explicar en lenguaje sencillo qué hace y por qué, y **esperar confirmación**.
- Código claro y **comentado en español**. Documentación en español con tono profesional de proyecto demostrativo (no de tutorial ni de aprendizaje).
- **Antes de cada `terraform apply`**, recordar revisar el plan (número de recursos, regla SSH con la IP propia `/32`, tamaño y región).
- **Al terminar cada sesión con infraestructura creada**, recordar `terraform destroy` para no generar costes.
- **Capturas:** en cada paso, avisar con 📸 cuando toque una captura, con su nombre de archivo y qué datos tapar. Mantener `docs/capturas/LEEME.md` sincronizado con las capturas reales (incluidas las divididas en `a`/`b`/`c`).
- **Incidencias:** toda incidencia nueva se documenta en `docs/TROUBLESHOOTING.md` (síntoma, causa, solución, prevención), numerada y agrupada por fase, y se resume en la sección de resolución de problemas del README.
- Los resultados reales que pegue el usuario (recaps, códigos HTTP...) se reflejan tal cual en el README, aunque difieran de lo esperado.

## Seguridad y Git

- **Nunca** subir a Git claves, IPs reales, IDs de suscripción o tenant, `terraform.tfvars`, `*.tfstate*`, `tfplan`/`*.tfplan` ni `ansible/inventory/hosts.ini`.
- En ejemplos y documentación, usar IPs de documentación (`203.0.113.x`) y marcadores (`<tenant>`, `<id>`).
- Antes del primer commit (y de cualquier commit con capturas nuevas), dar al usuario el comando de comprobación de secretos y recordarle revisar las capturas PNG a mano.
- `.terraform.lock.hcl` **sí** se versiona (hashes para `linux_amd64` y `windows_amd64`).

## Convenciones técnicas

- **Terraform:** `~> 1.17`, `azurerm ~> 5.14`, `local ~> 2.9`. Variables con validación, nombres en `locals.tf`, `terraform fmt` antes de validar. Registro de resource providers con `az provider register`, fuera del bloque `provider`.
- **Ansible:** módulos con FQCN (`ansible.builtin.*`), tareas idempotentes, handlers con `listen` (validar con `nginx -t` y después `reload`).
- La copia de la web se hace **archivo a archivo** (bucle con `fileglob`), porque `copy` con un directorio como origen no muestra el diff en `--check --diff`.

## Decisiones ya tomadas

- Región `spaincentral`; tamaño **`Standard_B2ts_v2`** (`Standard_B2ats_v2` dio `AllocationFailed`; B1s/B2s v1 no están disponibles en la región).
- Imagen `Canonical:ubuntu-24_04-lts:server:latest` (Gen2, x64). No usar tamaños ARM (con `p`).
- Prefijo de nombres `labweb`; carpeta de la web en la VM `/var/www/labweb`.
- State local (fuera de Git); `host_key_checking = False` **solo** por ser un laboratorio efímero.

## Restricciones

- **No modificar** los originales de la web en `C:\Cloud-DevOps\Cloud-Data_Projects\Terraform-Azure-Portfolio\web`; se trabaja sobre la copia en `ansible/roles/web/files/web/`.
