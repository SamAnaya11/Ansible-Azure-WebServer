# ---------------------------------------------------------------
# Salidas que se muestran al terminar terraform apply
# (y en cualquier momento con: terraform output)
# ---------------------------------------------------------------

output "ip_publica" {
  description = "IP pública estática de la VM."
  value       = azurerm_public_ip.pip.ip_address
}

output "url_web" {
  description = "URL de la web publicada por nginx (disponible tras ejecutar Ansible)."
  value       = "http://${azurerm_public_ip.pip.ip_address}"
}

output "comando_ssh" {
  description = "Comando para conectar a la VM por SSH desde WSL."
  value       = "ssh -i ${local.ruta_clave_privada} ${var.usuario_admin}@${azurerm_public_ip.pip.ip_address}"
}

output "inventario_ansible" {
  description = "Ruta del inventario de Ansible generado."
  value       = abspath(local_file.inventario_ansible.filename)
}
