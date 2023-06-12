# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider can also add additional subscriptions or regions from here
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "az-rg" {
  name     = "resources"
  location = "East US"
  tags = {
    environment = "dev"
    source      = "test"
    anything    = "yes"
  }
}

resource "azurerm_virtual_network" "az-network" {
  name                = "network"
  location            = azurerm_resource_group.az-rg.location
  resource_group_name = azurerm_resource_group.az-rg.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "dev"
    network     = "up"
  }
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet"
  resource_group_name  = azurerm_resource_group.az-rg.name
  virtual_network_name = azurerm_virtual_network.az-network.name
  address_prefixes     = ["10.0.1.0/24"]

}

resource "azurerm_network_security_group" "sg" {
  name                = "security_group"
  location            = azurerm_resource_group.az-rg.location
  resource_group_name = azurerm_resource_group.az-rg.name

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_rule" "sg_rule" {
  name                        = "dev_rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "136.36.177.148/32"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az-rg.name
  network_security_group_name = azurerm_network_security_group.sg.name
}

resource "azurerm_subnet_network_security_group_association" "sga" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.sg.id
}

resource "azurerm_public_ip" "pub_ip" {
  name                = "dev-ip"
  resource_group_name = azurerm_resource_group.az-rg.name
  location            = azurerm_resource_group.az-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "nic"
  location            = azurerm_resource_group.az-rg.location
  resource_group_name = azurerm_resource_group.az-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pub_ip.id
  }

  tags = {
    environment = "dev"
    VM          = "NIC"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm"
  resource_group_name = azurerm_resource_group.az-rg.name
  location            = azurerm_resource_group.az-rg.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("C:/Users/brian/.ssh/azkey.pub")
  }


  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address,
      user         = "adminuser",
      identityfile = "C:/Users/brian/.ssh/azkey"
    })
    interpreter = var.host_os == "windows" ? ["Powershell", "-Command"]:["bash", "-c"]
  }

  tags = {
    environment = "dev"
  }
}

data "azurerm_public_ip" "ip_data" {
    name = azurerm_public_ip.pub_ip.name
    resource_group_name = azurerm_resource_group.az-rg.name
}

output "public_ip_address" {
    value = "${azurerm_linux_virtual_machine.vm.name}: ${data.azurerm_public_ip.ip_data.ip_address}"
}