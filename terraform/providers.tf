# Configuración del provider de Azure.
#
# - La suscripción NO se escribe aquí: azurerm la lee de la variable de
#   entorno ARM_SUBSCRIPTION_ID (definida en ~/.bashrc de WSL).
# - La autenticación usa la sesión de Azure CLI (az login dentro de WSL).
# - El registro de resource providers (Microsoft.Compute y Microsoft.Network)
#   se hace una sola vez con "az provider register", fuera de Terraform.
provider "azurerm" {
  features {}
}
