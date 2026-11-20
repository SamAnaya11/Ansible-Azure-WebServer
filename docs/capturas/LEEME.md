# Capturas del proyecto

Lista de capturas en **orden de ejecución**, desde la preparación del entorno hasta la destrucción de la infraestructura. Las imágenes se guardan en esta misma carpeta (`docs/capturas/`) con el nombre indicado y en formato PNG.

## Reglas generales

**Antes de empezar a capturar**, simplifica el prompt de la terminal para que no aparezca `usuario@equipo`:

```bash
export PS1='\w\$ '      # muestra solo la ruta; dura hasta cerrar la terminal
```

**Datos que hay que tapar SIEMPRE que aparezcan** (rectángulo opaco, no desenfoque):

| Dato | Dónde suele aparecer |
|---|---|
| IP pública de la VM | outputs de Terraform, inventario, `ssh`, barra de direcciones del navegador |
| Tu IP pública (`ip_admin`) | plan de Terraform (regla SSH del NSG), `terraform.tfvars`, portal |
| ID de suscripción | `az account show`, IDs de recursos (`/subscriptions/<id>/...`), portal |
| ID de tenant (directorio) | `az account show`, `az login`, portal |
| Nombre de usuario / correo | prompt de la terminal, `az login`, esquina superior derecha del portal |
| Nombre de la suscripción | portal y `az account` (recomendable taparlo) |

**Nunca** captures el contenido de la clave privada (`~/.ssh/lab_azure_ed25519`) ni de `terraform.tfstate`.

Consejos: usa `Win + Shift + S` (Recortes) y captura solo la ventana de la terminal o del navegador. Usa un tamaño de fuente legible. Antes de guardar cada imagen, revisa que no quede ninguno de los datos de la tabla.

---

## Fase 0: preparación de WSL

Las capturas 01–06 se pueden hacer en cualquier momento, porque repiten comandos de solo lectura.

| Nº / Archivo | Paso exacto | Qué debe verse | Tapar |
|---|---|---|---|
| `01_wsl_versiones.png` | Tras instalar las herramientas. Comandos: `ansible --version \| head -1; terraform version; az version -o table` | `ansible [core 2.22.0]`, `Terraform v1.17.2 on linux_amd64`, `azure-cli 2.91.0` | Usuario del prompt (si no cambiaste `PS1`) |
| `02_wsl_clave_ssh.png` | Tras crear la clave. Comandos: `ls -l ~/.ssh/lab_azure_ed25519*; ssh-keygen -lf ~/.ssh/lab_azure_ed25519.pub` | Los dos archivos, la privada con permisos `-rw-------` (600), y la huella `ED25519` | Usuario propietario de los archivos en `ls -l`; usuario del prompt |
| `03_az_sesion_suscripcion.png` | Tras `az login` y fijar la suscripción. Comandos: `az account show --query "{suscripcion:name, estado:state}" -o table; [ -n "$ARM_SUBSCRIPTION_ID" ] && echo "ARM_SUBSCRIPTION_ID definido"` | Suscripción en estado `Enabled` y el mensaje `ARM_SUBSCRIPTION_ID definido` | Nombre de la suscripción. **No** ejecutes `echo $ARM_SUBSCRIPTION_ID` en pantalla |
| `04_az_tamanos_serie_b.png` | `az vm list-skus -l spaincentral --resource-type virtualMachines --size Standard_B2 --query "[?name=='Standard_B2ts_v2' \|\| name=='Standard_B2ats_v2'].{tamano:name, vCPU:capabilities[?name=='vCPUs'].value \| [0], memoriaGB:capabilities[?name=='MemoryGB'].value \| [0], arquitectura:capabilities[?name=='CpuArchitectureType'].value \| [0], restricciones:length(restrictions)}" -o table` | Tabla con `Standard_B2ts_v2` (tamaño usado) y `Standard_B2ats_v2` (2 vCPU, 1 GB, x64) | Usuario del prompt |
| `05_az_imagen_ubuntu.png` | `az vm image show -l spaincentral --urn Canonical:ubuntu-24_04-lts:server:latest --query "{version:name, generacion:hyperVGeneration, arquitectura:architecture}" -o table` | Versión `24.04.x`, generación `V2`, arquitectura `x64` | Usuario del prompt |
| `06_az_resource_providers.png` | `for ns in Microsoft.Compute Microsoft.Network; do echo "$ns: $(az provider show -n $ns --query registrationState -o tsv)"; done` | `Microsoft.Compute: Registered` y `Microsoft.Network: Registered` | Usuario del prompt |

## Fase 1: Terraform

| Nº / Archivo | Paso exacto | Qué debe verse | Tapar |
|---|---|---|---|
| `07_terraform_init.png` | `terraform init` | Versiones instaladas de `hashicorp/azurerm` (5.14.x) y `hashicorp/local` (2.9.x) y `Terraform has been successfully initialized!` | Usuario del prompt |
| `08_terraform_providers_lock.png` | `terraform providers lock -platform=linux_amd64 -platform=windows_amd64` | Hashes obtenidos para `linux_amd64` y `windows_amd64` | Usuario del prompt |
| `09_terraform_validate.png` | `terraform fmt -recursive` seguido de `terraform validate` | `Success! The configuration is valid.` | Usuario del prompt |
| `10_terraform_plan_nsg.png` | `terraform plan -out=tfplan` y después `terraform show tfplan \| grep -B 9 -A 9 'name *= "permitir'` para mostrar las reglas del NSG. *Esta captura se hizo tras la destrucción, con `ip_admin` actualizada y un plan que no se aplicó; `tfplan` se borró después.* | Las dos reglas: 80 desde `Internet` y 22 desde `<tu IP>/32` | **Tu IP** en `source_address_prefix` de la regla SSH |
| `11_terraform_plan_resumen.png` | Final del mismo plan | `Plan: 9 to add, 0 to change, 0 to destroy.` y los outputs `(known after apply)` | Usuario del prompt |
| `12a_allocation_failed.png` *(opcional)* | Primer `terraform apply` fallido con `Standard_B2ats_v2` | Error `AllocationFailed` en `azurerm_linux_virtual_machine.vm` y la sugerencia de Azure (`Standard_B2ts_v2`) | **ID de suscripción** en las rutas `/subscriptions/<id>/...`; tu IP o la de la VM si aparecen |
| `12_terraform_apply.png` | `terraform apply tfplan` (tras revisar el plan) | En esta ejecución, `Apply complete! Resources: 1 added, 0 changed, 0 destroyed.` y los outputs. Solo faltaba la VM: los otros 8 recursos se crearon en el apply fallido (ver 12a y `docs/TROUBLESHOOTING.md`, incidencias 7 y 8). *Nota: en una ejecución limpia el resultado es `Resources: 9 added`.* | **IP de la VM** en `ip_publica`, `url_web` y `comando_ssh` |
| `13_portal_grupo_recursos.png` | Portal de Azure → Grupos de recursos → `rg-labweb` | Los 6 recursos del grupo: VM, disco del SO, NIC, IP pública, NSG y VNet (la subred y la asociación NSG‑subred van dentro de la VNet; el inventario es un archivo local), sin duplicados, y las etiquetas | Nombre e ID de suscripción, correo/usuario y directorio (arriba a la derecha) |
| `14_inventario_generado.png` | `cat ../ansible/inventory/hosts.ini` | Cabecera "ARCHIVO GENERADO POR TERRAFORM", grupo `[web]` y la línea `vm-labweb ansible_host=...` | **IP de la VM** (`ansible_host`); el usuario `azureuser` puede verse |

## Fase 2: Ansible (conectividad)

| Nº / Archivo | Paso exacto | Qué debe verse | Tapar |
|---|---|---|---|
| `15_ansible_ping.png` | `ansible web -m ping` desde la carpeta `ansible/` con `ANSIBLE_CONFIG` definido | `vm-labweb \| SUCCESS` y `"ping": "pong"` | Usuario del prompt; la IP si aparece en algún aviso |

## Fase 3: experimentos

| Nº / Archivo | Paso exacto | Qué debe verse | Tapar |
|---|---|---|---|
| `16a_expA_primera_ejecucion.png` | **A.** Primera ejecución: `ansible-playbook site.yml` (la salida ocupa tres pantallas) | Primera parte: `PLAY [Configurar servidor web nginx]`, `Gathering Facts` y las primeras tareas en amarillo (`changed`) | IP si aparece |
| `16b_expA_primera_ejecucion.png` | **A.** Continuación de la misma salida | Resto de tareas del rol (plantilla, sitio, copia de la web, servicio) | IP si aparece |
| `16c_expA_primera_ejecucion.png` | **A.** Final de la misma salida | `RUNNING HANDLER [web : Validar la configuración de nginx]`, `RUNNING HANDLER [web : Recargar nginx]` y `PLAY RECAP`: `ok=11 changed=8 unreachable=0 failed=0` | IP si aparece |
| `17_expA_web_navegador.png` | **A.** Abrir `http://<IP>` en el navegador | La web publicada | **Barra de direcciones** (IP de la VM) |
| `18a_expB_idempotencia.png` | **B.** Segunda ejecución sin cambios: `ansible-playbook site.yml` (la salida ocupa dos pantallas) | Primera parte de las tareas, todas en verde (`ok`) | IP si aparece |
| `18b_expB_idempotencia.png` | **B.** Final de la misma salida | Resto de tareas en `ok`, ninguna línea `RUNNING HANDLER` y `PLAY RECAP`: `ok=9 changed=0 unreachable=0 failed=0` | IP si aparece |
| `19_expC_check_diff.png` | **C.** Tras cambiar un texto de `index.html` del rol: `ansible-playbook site.yml --check --diff` | Bloque de diff (`-` texto antiguo, `+` texto nuevo) y `changed=1` sin aplicar | IP si aparece |
| `20_expC_aplicado.png` | **C.** Aplicar el cambio: `ansible-playbook site.yml` | La tarea de copia de la web en `changed` y `PLAY RECAP` con `changed=1` | IP si aparece |
| `21_expC_web_actualizada.png` | **C.** Recargar la web en el navegador (Ctrl+F5) | El texto nuevo visible | **Barra de direcciones** |
| `22_expD_handler_ejecutado.png` | **D.** Tras modificar la plantilla de nginx del rol: `ansible-playbook site.yml` | La tarea de la plantilla en `changed`, `RUNNING HANDLER [web : ...]` y `changed` ≥ 2 | IP si aparece |
| `23_expD_handler_no_ejecutado.png` | **D.** Volver a ejecutar sin cambiar nada | Sin la línea `RUNNING HANDLER` y `changed=0` | IP si aparece |
| `24_expE_borrado_manual.png` | **E.** Por SSH: borrar `index.html` en la VM y comprobar con `curl -I` que la web ya no responde 200 | El comando `rm`, la comprobación de que el archivo no existe y la respuesta de error (403/404) | **IP de la VM** en el comando `ssh`, en el prompt remoto (`azureuser@vm-labweb` puede verse) y en el `curl` |
| `24b_expE_drift_detectado.png` | **E.** Antes de restaurar: `ansible-playbook site.yml --check --diff` | Tarea de copia: `index.html` en `changed` con diff de archivo nuevo; `PLAY RECAP` con `ok=9 changed=1` (detecta el drift sin corregirlo) | IP si aparece |
| `25_expE_restaurado.png` | **E.** `ansible-playbook site.yml` y después `curl -I http://<IP>` | Solo la tarea de copia de la web en `changed` (`changed=1`) y `HTTP/1.1 200 OK` | **IP de la VM** en el `curl` |

## Fase 3F: destrucción

| Nº / Archivo | Paso exacto | Qué debe verse | Tapar |
|---|---|---|---|
| `26_terraform_destroy_plan.png` | Tras `terraform plan -destroy -out=destroy.tfplan`: `terraform show destroy.tfplan \| grep -E "will be destroyed\|^Plan:"` | Los 9 recursos con `will be destroyed` y `Plan: 0 to add, 0 to change, 9 to destroy.` | IDs `/subscriptions/...` si aparecen |
| `27a_terraform_destroy_completado.png` | `terraform apply destroy.tfplan` | Las líneas `Destruction complete after ...` de cada recurso, hasta `azurerm_resource_group.rg: Destruction complete after 26s` | IDs `/subscriptions/...` si aparecen |
| `27b_terraform_state_vacio.png` | `terraform show` y `terraform state list \| wc -l` | `The state file is empty. No resources are represented.` y `0` | Usuario del prompt |
| `28_az_grupo_eliminado.png` | `az group exists -n rg-labweb` | `false` | Usuario del prompt |

## Fase 4: publicación (opcional)

| Nº / Archivo | Paso exacto | Qué debe verse | Tapar |
|---|---|---|---|
| `29_git_comprobacion_secretos.png` | Comando de comprobación de secretos antes del primer commit | Sin coincidencias de claves, IPs ni IDs reales | Usuario del prompt |
