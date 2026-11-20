# ---------------------------------------------------------------
# Valores calculados: nombres, etiquetas e imagen.
# Centralizarlos aquí evita repetir cadenas en main.tf.
# ---------------------------------------------------------------
locals {
  # Nombres siguiendo las abreviaturas recomendadas por Microsoft (CAF)
  nombres = {
    grupo_recursos = "rg-${var.prefijo}"
    vnet           = "vnet-${var.prefijo}"
    subred         = "snet-${var.prefijo}-web"
    nsg            = "nsg-${var.prefijo}-web"
    ip_publica     = "pip-${var.prefijo}"
    nic            = "nic-${var.prefijo}"
    vm             = "vm-${var.prefijo}"
    disco_os       = "osdisk-${var.prefijo}"
  }

  # Etiquetas comunes aplicadas a todos los recursos que las admiten
  etiquetas = {
    proyecto       = "ansible-azure-webserver"
    entorno        = "lab"
    gestionado_por = "terraform"
    prefijo        = var.prefijo
  }

  # Imagen Ubuntu Server 24.04 LTS (Gen2, x64), verificada en spaincentral
  imagen = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  # Contenido de la clave pública y ruta de la privada (misma ruta sin .pub)
  clave_publica      = file(pathexpand(var.ruta_clave_publica))
  ruta_clave_privada = trimsuffix(var.ruta_clave_publica, ".pub")
}
