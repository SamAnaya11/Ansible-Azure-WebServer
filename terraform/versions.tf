# Versiones de Terraform y de los providers.
# "~>" (restricción pesimista) permite parches y versiones menores,
# pero impide saltar a una versión mayor con cambios incompatibles.
terraform {
  required_version = "~> 1.17"

  required_providers {
    # Recursos de Azure (red, VM, IP pública...)
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.14"
    }

    # Escritura de archivos locales (inventario de Ansible)
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9"
    }
  }
}
