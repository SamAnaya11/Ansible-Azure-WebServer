# ---------------------------------------------------------------
# Infraestructura: grupo de recursos, red, seguridad y VM Linux.
# ---------------------------------------------------------------

# Grupo de recursos: contenedor de todo el laboratorio.
# terraform destroy lo elimina junto con todo su contenido.
resource "azurerm_resource_group" "rg" {
  name     = local.nombres.grupo_recursos
  location = var.ubicacion
  tags     = local.etiquetas
}

# Red virtual privada del laboratorio
resource "azurerm_virtual_network" "vnet" {
  name                = local.nombres.vnet
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.10.0.0/16"]
  tags                = local.etiquetas
}

# Subred donde vive la VM
resource "azurerm_subnet" "snet" {
  name                 = local.nombres.subred
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

# Grupo de seguridad de red (firewall a nivel de subred).
# Solo se abren dos puertos de entrada; el resto lo bloquean
# las reglas por defecto de Azure (DenyAllInBound).
resource "azurerm_network_security_group" "nsg" {
  name                = local.nombres.nsg
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.etiquetas

  # HTTP abierto a Internet: la web es pública
  security_rule {
    name                       = "permitir-http-internet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # SSH solo desde la IP del administrador (/32 = una única IP)
  security_rule {
    name                       = "permitir-ssh-admin"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${var.ip_admin}/32"
    destination_address_prefix = "*"
  }
}

# Asociación del NSG a la subred: las reglas aplican a todo lo que haya en ella
resource "azurerm_subnet_network_security_group_association" "snet_nsg" {
  subnet_id                 = azurerm_subnet.snet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# IP pública estática, SKU Standard (la SKU Basic está retirada).
# La SKU Standard es "segura por defecto": bloquea la entrada salvo
# que un NSG la permita, por eso el NSG anterior es imprescindible.
resource "azurerm_public_ip" "pip" {
  name                = local.nombres.ip_publica
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.etiquetas
}

# Interfaz de red de la VM: IP privada dinámica en la subred + IP pública
resource "azurerm_network_interface" "nic" {
  name                = local.nombres.nic
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.etiquetas

  ip_configuration {
    name                          = "ipconfig-principal"
    subnet_id                     = azurerm_subnet.snet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

# Máquina virtual Linux con autenticación SOLO por clave SSH
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = local.nombres.vm
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = var.tamano_vm
  admin_username        = var.usuario_admin
  network_interface_ids = [azurerm_network_interface.nic.id]
  tags                  = local.etiquetas

  # Sin contraseña: el único acceso es la clave SSH declarada abajo
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.usuario_admin
    public_key = local.clave_publica
  }

  # Disco del sistema en HDD estándar (la opción más barata)
  os_disk {
    name                 = local.nombres.disco_os
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = local.imagen.publisher
    offer     = local.imagen.offer
    sku       = local.imagen.sku
    version   = local.imagen.version
  }

  # La VM debe crearse cuando el NSG ya protege la subred
  depends_on = [azurerm_subnet_network_security_group_association.snet_nsg]
}
