# Resolución de problemas

Incidencias encontradas durante la ejecución del proyecto, con su causa, la solución aplicada y cómo evitarlas. Están agrupadas por fase y en orden cronológico.

---

## Fase 0: preparación del entorno (Windows 11 + WSL 2)

### 1. WSL no estaba instalado

**Síntoma.** Windows 11 no tenía WSL ni ninguna distribución de Linux.

**Solución.** En PowerShell **como administrador**, instalar WSL con Ubuntu y reiniciar el equipo:
```powershell
wsl --install -d Ubuntu
```
Tras el reinicio, Ubuntu se abre por primera vez y pide crear un usuario Linux. Ver la incidencia 2.

**Comprobación.** `wsl -l -v` debe mostrar `Ubuntu` con `VERSION 2`.

### 2. `Invalid username` al crear el usuario de Ubuntu

**Síntoma.** Durante la primera ejecución de Ubuntu, el nombre de usuario propuesto se rechazó con `Invalid username`.

**Causa.** Un nombre de usuario de Linux debe empezar por una letra minúscula (o `_`) y solo puede contener minúsculas, dígitos, `_` o `-`. No admite mayúsculas, espacios ni acentos.

**Solución.** Elegir un nombre que cumpla esas reglas, por ejemplo `sam` o `sam_lab`. Es independiente del usuario de Windows.

### 3. Comandos ejecutados en Git Bash en lugar de Ubuntu (WSL)

**Síntoma.** Parte de la preparación (herramientas, `ARM_SUBSCRIPTION_ID` en `~/.bashrc` y la clave SSH) se hizo en Git Bash. Al pasar a Ubuntu, nada de eso existía.

**Causa.** Git Bash y Ubuntu (WSL) son entornos distintos, cada uno con su propio `~`, su `~/.bashrc` y su `~/.ssh`. Sus terminales se parecen mucho.

**Solución.** Repetir en Ubuntu la instalación de las herramientas, la línea de `ARM_SUBSCRIPTION_ID` en `~/.bashrc` y la generación de la clave SSH.

**Prevención.** Identificar la terminal por el prompt. En Ubuntu aparece `usuario@equipo:~$` y la ruta del proyecto empieza por `/mnt/c/...`; en Git Bash aparece `MINGW64` y las rutas empiezan por `/c/...`. Para salir de dudas: `uname -a` (en WSL contiene `microsoft-standard-WSL2`).

### 4. `AADSTS530035: Access has been blocked by security defaults`

**Síntoma.** Tras `az login --use-device-code`, las consultas `az vm ...` fallaban con `AADSTS530035`.

**Causa.** Los *security defaults* de Microsoft Entra ID bloquean el flujo de código de dispositivo en este tenant.

**Solución.**
```bash
az logout
az login --tenant <tenant> --scope "https://management.core.windows.net//.default"
```
Es un login interactivo en el navegador, sin `--use-device-code`.

### 5. `ARM_SUBSCRIPTION_ID` con un `\r` final

**Síntoma.** El ID de suscripción llegaba con un retorno de carro (`\r`) al final, y Terraform no lo reconocía como suscripción válida.

**Causa.** En Ubuntu respondía el **Azure CLI de Windows** (`az.cmd`). WSL añade el PATH de Windows al de Linux, así que, sin un `az` de Linux instalado, se ejecutaba el de Windows, que devuelve finales de línea CRLF.

**Solución.** Instalar el Azure CLI de Linux dentro de Ubuntu e iniciar sesión con él. `gio` no podía abrir el navegador desde WSL, así que se copió la URL del login al navegador de Windows.

**Prevención.**
- Comprobar qué `az` responde con `which az`: debe ser `/usr/bin/az`, nunca una ruta `/mnt/c/...`.
- Opcional: desactivar la integración del PATH de Windows añadiendo esto a `/etc/wsl.conf` y ejecutando `wsl --shutdown` desde Windows:
  ```ini
  [interop]
  appendWindowsPath = false
  ```

---

## Fase 1: Terraform

### 6. `ip_admin` rechaza una IPv6

**Síntoma.** `terraform plan` falló en la validación de la variable `ip_admin`.

**Causa.** `curl https://ifconfig.me` devolvió la IPv6 de la conexión, y la variable solo admite IPv4. La regla SSH del NSG se construye como `<IPv4>/32`.

**Solución.** Forzar IPv4 y escribirla en `terraform.tfvars`:
```bash
IP=$(curl -4 -s https://ifconfig.me)
sed -i "s/^ip_admin *=.*/ip_admin = \"$IP\"/" terraform.tfvars
```

**Prevención.** Usar siempre `curl -4`. La validación de la variable cumplió su función: detuvo el error antes de llegar a Azure.

### 7. `AllocationFailed` al crear la VM (`Standard_B2ats_v2`)

**Síntoma.** El primer `terraform apply` creó 8 de los 9 recursos, pero `azurerm_linux_virtual_machine.vm` falló con `AllocationFailed`. Azure sugirió usar `Standard_B2ts_v2`.

**Causa.** Azure no tenía capacidad física disponible para ese tamaño en `spaincentral` en ese momento. No es un problema de cuota ni de configuración: un tamaño puede aparecer como disponible en `az vm list-skus` y aun así no tener capacidad puntual.

**Solución.** Cambiar a `Standard_B2ts_v2`, el equivalente Intel con 2 vCPU y 1 GB, en `terraform.tfvars`. También pasó a ser el valor por defecto en `variables.tf` y `terraform.tfvars.example`.

**Qué pasó con el state.** Terraform guarda en el state **cada recurso a medida que se crea**, no al final del `apply`. Por eso los 8 recursos que se crearon bien (grupo de recursos, red, NSG, IP pública, NIC…) quedaron registrados, y el siguiente `apply` solo intentó crear lo que faltaba. No hay rollback automático: un `apply` fallido deja la infraestructura a medias pero coherente con el state.

### 8. `a resource with the ID ".../virtualMachines/vm-labweb" already exists`

**Síntoma.** El `apply` siguiente, ya con el nuevo tamaño, falló con:
```
a resource with the ID "/subscriptions/<id>/resourceGroups/rg-labweb/providers/Microsoft.Compute/virtualMachines/vm-labweb" already exists - to be managed via Terraform this resource needs to be imported into the State
```

**Causa.** El `AllocationFailed` no impidió que Azure creara el objeto VM. La VM quedó en estado `Failed`, junto con su disco del sistema operativo (`osdisk-labweb`). Pero la operación devolvió error, así que **Terraform no los registró en el state**. Quedaron como **recursos huérfanos**: existen en Azure pero Terraform no sabe que son suyos, y por eso se negó a crear otra VM con el mismo nombre.

**Solución.** Borrar los huérfanos con Azure CLI y volver a planificar. El orden importa: un disco no se puede borrar mientras está asociado a una VM.
```bash
az vm delete   -g rg-labweb -n vm-labweb     --yes
az disk delete -g rg-labweb -n osdisk-labweb --yes
az disk list   -g rg-labweb -o table          # comprobar que no queda ningún disco
terraform plan -out=tfplan                    # debe proponer 1 to add (la VM)
terraform apply tfplan
```

**Por qué borrar en lugar de `terraform import`.** `terraform import` (o un bloque `import {}`) sirve para que Terraform adopte un recurso **sano** que interesa conservar, por ejemplo uno con datos o creado a mano. Aquí no se cumplía ninguna de esas condiciones:
- **La VM estaba en estado `Failed`.** Importarla habría metido en el state un recurso roto, que de todos modos habría que reparar o recrear.
- **El tamaño había cambiado** de `B2ats_v2` a `B2ts_v2`. Tras el import, el siguiente plan habría propuesto un redimensionado o una sustitución, sobre una VM que nunca llegó a arrancar.
- **El disco no contenía datos** (la VM no llegó a funcionar) y el entorno es desechable.
- **Borrar y recrear deja el state limpio.** El resultado es el mismo que en un despliegue desde cero, que es justo lo que este proyecto quiere demostrar.

**Prevención y diagnóstico (huérfanos).** Tras un `apply` fallido, comprobar si quedaron recursos fuera del state comparando lo que hay en Azure con lo que conoce Terraform:
```bash
az resource list -g rg-labweb --query "[].{nombre:name, tipo:type}" -o table
terraform state list
```

---

## Fase 3: experimentos con Ansible

### 9. `--check --diff` marca la copia de la web como `changed` pero no muestra el diff

**Síntoma.** En el experimento C, tras cambiar un texto de `roles/web/files/web/index.html`, `ansible-playbook site.yml --check --diff` marcó la tarea «Copiar los archivos de la web» como `changed` (`ok=9 changed=1`). Sin embargo, no mostró ningún bloque de diff: no aparecían las líneas `-` y `+` de `index.html`.

**Causa.** La tarea copiaba el **directorio completo** (`src: web/`) con `ansible.builtin.copy`. Con un directorio como origen, el módulo detecta qué archivos difieren y los reporta como cambio, pero no genera el diff de su contenido. El diff solo se muestra cuando `src` es un archivo individual.

**Solución.** Copiar los archivos **uno a uno** con un bucle sobre `files/web/`:
```yaml
- name: Copiar los archivos de la web
  ansible.builtin.copy:
    src: "{{ item }}"
    dest: "{{ web_raiz }}/{{ item | basename }}"
    owner: root
    group: root
    mode: "0644"
  loop: "{{ lookup('ansible.builtin.fileglob', 'web/*', wantlist=True) | sort }}"
  loop_control:
    label: "{{ item | basename }}"
```
- `fileglob` busca dentro de `files/` del rol y devuelve los archivos de primer nivel; un archivo nuevo en `files/web/` se incluye sin tocar la tarea.
- `sort` mantiene un orden estable en la salida.
- `label` muestra solo el nombre del archivo, en lugar de la ruta completa del controlador.

**Efecto en los resultados.** Ninguno en los recaps. Un bucle sigue siendo **una sola tarea** en el `PLAY RECAP`: cuenta como `changed` si cambia al menos un elemento y como `ok` si no cambia ninguno. La A sigue dando `ok=11 changed=8` y la B `ok=9 changed=0`. Lo único distinto es que la salida muestra una línea por archivo (`ok: [vm-labweb] => (item=estilos.css)`, `changed: ... (item=index.html)`).

**Limitación.** `fileglob` no recorre subcarpetas. Si la web tuviera carpetas (por ejemplo `img/`), habría que usar `ansible.builtin.find` con `delegate_to: localhost` o recorrer el árbol con el lookup `community.general.filetree`.

---

## Fase 4: publicación en Git

### 10. Datos sensibles en capturas que la comprobación de secretos no detecta

**Síntoma.** La comprobación de secretos previa al primer commit (captura 29) dio `OK` en las seis comprobaciones. Sin embargo, la revisión manual de las capturas encontró datos que había que tapar en `02_wsl_clave_ssh.png`, `12_terraform_apply.png` y `14_inventario_generado.png`. Tras corregirlas, `git status --short` las mostraba como `AM` en lugar de `A`.

**Causa.**
- `git grep` (y cualquier búsqueda de texto) **no puede revisar imágenes**: el texto de una captura son píxeles, no caracteres. Además, `.gitattributes` marca `*.png` como `binary` y `-I` las excluye de la búsqueda.
- `git add` guarda en el índice una **copia del archivo en ese momento**. Si el archivo se modifica después, el commit lleva la versión del índice, no la corregida. `AM` significa precisamente eso: añadido al índice (`A`) y modificado después en el directorio de trabajo (`M`).

**Solución.** Volver a añadir las imágenes corregidas y comprobar que todas quedan solo como `A`:
```bash
git add docs/capturas/
git status --short docs/capturas/       # todas con "A ", ninguna con "AM"
```

**Prevención.**
- Revisar **a mano** todas las capturas antes del commit, además de la comprobación automática: IPs, IDs de suscripción y tenant, nombre de la suscripción, usuario y correo.
- Tapar los datos **antes** del `git add`, o repetir el `git add` tras cualquier corrección.
- Justo antes de `git commit`, comprobar que `git status --short` no muestra ninguna `M` en la segunda columna.
