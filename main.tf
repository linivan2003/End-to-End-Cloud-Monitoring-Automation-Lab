resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}

# Create virtual network
resource "azurerm_virtual_network" "my_terraform_network" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "my_terraform_subnet" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "my_terraform_public_ip" {
  name                = "myPublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "myNetworkSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "my_terraform_nic" {
  name                = "myNIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "my_nic_configuration"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.my_terraform_nic.id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "my_storage_account" {
  name                     = "diag${random_id.random_id.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "my_terraform_vm" {
  name                  = "myVM"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.my_terraform_nic.id]
  size                  = "Standard_B2ms"

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name  = "hostname"
  admin_username = var.username

  admin_ssh_key {
    username   = var.username
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCd9Z7+vKc7da05YwmJ0gpxvvabkoPuI8unKu0xY7rE892Qqw34HMIlzwNJnSgq+Ndz5vZv9ByFqTxlc2BKkv8NCCgQ9XKuHZD/3SjmNHbiaiqtS+g5TsY7m9suiqyLkYf1lav3Je+9uxTs2iC/JuqhXzmF8YFWxgD6Nfm4NyawTsSRW9xrG1gcX+ev/EQqPgpcSeKVg5m+CzFr8Gc3b4jteN0HzXA5mC4GF8nISMKQc2CL5v/W3RZg0RbU/haHtBGmGtBL9eDxtcW24N4BRXz6hLQdULLXqSSDs5nRj+k2t+mMafKXpCth5LUDoyjzm9NgAtoEv2CyGRGnoIJP3WHeksiiasEH9WbG0lQfFDIylAVlVesX59sdqmLWjaemiJXUEk+qvRy/q9Y0PjfgTSwmZIOMQmUITDE/bN6dwOa5zCp4wyQn0m+K9Fk0q7LmLI4dcHRqv4lL8J9cwYNjL1KvQRV7lD+wlcan36VMqAOQ50H6QQdpprWnqb0MSVwoXqbPMcmyYyCIoyqOe00OsIM6zVz5t5FSQUf8oSIT2xQDHHnJrUFJrBbF9R1FswxBflGxSdAZ1Letl5Mas/9OqllEWt4wRKKmtovw84/aDh+ehYh/pBbUuROUbE/9pP5uhC64mA2pi8ZOhVWI3RqVmARy04MNe1vLGgadK+kZRI4hlQ== linivan2003@gmail.com"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }
}