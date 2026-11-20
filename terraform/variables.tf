# ---------------------------------------------------------------
# Variables de entrada. Cada una valida su valor antes de llegar
# a Azure, para fallar pronto y con un mensaje claro.
# ---------------------------------------------------------------

variable "prefijo" {
  description = "Prefijo para los nombres de todos los recursos (3-10 caracteres, minúsculas y números, empezando por letra)."
  type        = string
  default     = "labweb"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,9}$", var.prefijo))
    error_message = "El prefijo debe tener 3-10 caracteres, solo minúsculas y números, y empezar por una letra."
  }
}

variable "ubicacion" {
  description = "Región de Azure donde se despliegan los recursos."
  type        = string
  default     = "spaincentral"

  validation {
    # Los nombres de región de Azure son minúsculas y números, sin espacios.
    condition     = can(regex("^[a-z]+[a-z0-9]*$", var.ubicacion))
    error_message = "La región debe escribirse con su nombre corto en minúsculas, por ejemplo: spaincentral."
  }
}

variable "tamano_vm" {
  description = "Tamaño de la VM. Debe ser de la serie B (burstable) y de arquitectura x64."
  type        = string
  # B2ts_v2 (Intel, 2 vCPU, 1 GB): B2ats_v2 falló con AllocationFailed en spaincentral
  default = "Standard_B2ts_v2"

  validation {
    # Serie B con sufijos de letras SIN "p": la "p" indica ARM (p. ej. B2pts_v2),
    # que no es compatible con la imagen x64 de Ubuntu elegida.
    condition     = can(regex("^Standard_B[0-9]+[a-oq-z]*(_v[0-9]+)?$", var.tamano_vm))
    error_message = "El tamaño debe ser de la serie B x64 (por ejemplo Standard_B2ts_v2). Los tamaños con 'p' son ARM y no se admiten."
  }
}

variable "ip_admin" {
  description = "Tu IP pública IPv4 (sin máscara). Es la única que podrá conectar por SSH (puerto 22)."
  type        = string

  validation {
    # Formato x.x.x.x y que cidrhost() la acepte (octetos 0-255).
    condition = (
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.ip_admin)) &&
      can(cidrhost("${var.ip_admin}/32", 0)) &&
      var.ip_admin != "0.0.0.0"
    )
    error_message = "ip_admin debe ser una IPv4 válida sin máscara, por ejemplo 203.0.113.10 (obtenla con: curl -4 -s https://ifconfig.me)."
  }
}

variable "ruta_clave_publica" {
  description = "Ruta de la clave pública SSH dentro de WSL. Admite ~ (se expande con pathexpand)."
  type        = string
  default     = "~/.ssh/lab_azure_ed25519.pub"

  validation {
    condition     = endswith(var.ruta_clave_publica, ".pub") && fileexists(pathexpand(var.ruta_clave_publica))
    error_message = "La ruta debe apuntar a un archivo .pub existente (por ejemplo ~/.ssh/lab_azure_ed25519.pub). Recuerda que la clave vive en WSL, no en /mnt/c."
  }
}

variable "usuario_admin" {
  description = "Usuario administrador de la VM (el que usará Ansible para conectar)."
  type        = string
  default     = "azureuser"

  validation {
    # Azure rechaza ciertos nombres reservados y exige un formato de usuario Linux.
    condition = (
      can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.usuario_admin)) &&
      !contains(["root", "admin", "administrator", "adm", "guest", "test", "user", "sys", "daemon", "bin"], var.usuario_admin)
    )
    error_message = "Usuario no válido: usa minúsculas, números, '_' o '-', y evita nombres reservados como root o admin."
  }
}
