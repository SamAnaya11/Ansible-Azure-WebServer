# ---------------------------------------------------------------
# Puente Terraform -> Ansible: genera el inventario a partir de la
# IP real de la VM. Si la VM se recrea, el inventario se actualiza
# solo en el siguiente apply. El archivo está en .gitignore.
# ---------------------------------------------------------------
resource "local_file" "inventario_ansible" {
  filename        = "${path.module}/../ansible/inventory/hosts.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/inventory.ini.tftpl", {
    nombre_host = local.nombres.vm
    ip_publica  = azurerm_public_ip.pip.ip_address
    usuario     = var.usuario_admin
  })
}
