provider "azurerm" {
  features {}
}

locals {
  resource_group_name="TAM-Americas-RG"
  resource_group_location= "West US"
  tag_owner = "axel.ramirez@uipath.com"
  tag_project = "TAM"
  tag_AlwaysPoweredOn = "true"
  vm_size = "Standard_E4s_v3"
}

#########################################################################
#############################NETWORK#####################################
#########################################################################

resource "azurerm_virtual_network" "example" {
  name                = "ar-vnet-01"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  address_space       = ["10.0.0.0/16"]

  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
    "AlwaysPoweredOn" = local.tag_AlwaysPoweredOn
  }
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Sql"]
}

resource "azurerm_lb" "orchestrator-vmss-lb" {
  name                = "ar-orchestratorlb-01"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name

  sku = "Standard"

  frontend_ip_configuration {
    name      = "privateIPAddress"
    subnet_id = azurerm_subnet.internal.id
    private_ip_address_allocation = "Static"
    private_ip_address = "10.0.2.7"
  }
  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
    "AlwaysPoweredOn" = local.tag_AlwaysPoweredOn
  }
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  resource_group_name = local.resource_group_name
  loadbalancer_id     = azurerm_lb.orchestrator-vmss-lb.id
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "vmss" {
  resource_group_name = local.resource_group_name
  loadbalancer_id     = azurerm_lb.orchestrator-vmss-lb.id
  name                = "ssh-running-probe"
  port                = "443"
}

resource "azurerm_lb_rule" "lbnatrule" {
  resource_group_name            = local.resource_group_name
  loadbalancer_id                = azurerm_lb.orchestrator-vmss-lb.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = "443"
  backend_port                   = "443"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.bpepool.id
  frontend_ip_configuration_name = "privateIPAddress"
  probe_id                       = azurerm_lb_probe.vmss.id
  load_distribution = "SourceIPProtocol"
}

resource "azurerm_network_interface_backend_address_pool_association" "orch1" {
  network_interface_id    = azurerm_network_interface.orch1_interface.id
  ip_configuration_name   = "ip-configuration-1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bpepool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "orch2" {
  network_interface_id    = azurerm_network_interface.orch2_interface.id
  ip_configuration_name   = "ip-configuration-2"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bpepool.id
}

#########################################################################
#############################Domain Controller###########################
#########################################################################

resource "azurerm_network_interface" "dc_interface" {
  name                = "ar-dc-acctni01"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "testconfiguration"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "dynamic"
    private_ip_address = "10.0.2.7"
    public_ip_address_id          = azurerm_public_ip.example.id
  }
  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
    "AlwaysPoweredOn" = local.tag_AlwaysPoweredOn
  }
}

resource "azurerm_public_ip" "example" {
  name                = "ar-publicip-01"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  allocation_method   = "Static"
  sku = "Standard"

  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
    "AlwaysPoweredOn" = local.tag_AlwaysPoweredOn
  }
}

resource "azurerm_windows_virtual_machine" "dc_vm" {
  name                = "ar-dc-01"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  size                = local.vm_size
  admin_username      = "uipathadmin"
  admin_password      = "M1cr0s0ft"
  network_interface_ids = [azurerm_network_interface.dc_interface.id,]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
    "AlwaysPoweredOn" = local.tag_AlwaysPoweredOn
  }
}

#########################################################################
#############################Orchestrator################################
#########################################################################

resource "azurerm_network_interface" "orch1_interface" {
  name                = "ar-orch-acctni-01"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "ip-configuration-1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "dynamic"
    private_ip_address = "10.0.2.8"
  }
  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
    "AlwaysPoweredOn" = local.tag_AlwaysPoweredOn
  }
}

resource "azurerm_windows_virtual_machine" "orch_vm1" {
  name                = "ar-orch-01"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  size                = local.vm_size
  admin_username      = "uipathadmin"
  admin_password      = "M1cr0s0ft"
  network_interface_ids = [azurerm_network_interface.orch1_interface.id,]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
    "AlwaysPoweredOn" = local.tag_AlwaysPoweredOn
  }
}

resource "azurerm_network_interface" "orch2_interface" {
  name                = "ar-orch-acctni-02"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "ip-configuration-2"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "dynamic"
    private_ip_address = "10.0.2.9"
  }
  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
    "AlwaysPoweredOn" = local.tag_AlwaysPoweredOn
  }
}

resource "azurerm_windows_virtual_machine" "orch2_vm" {
  name                = "ar-orch-02"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  size                = local.vm_size
  admin_username      = "uipathadmin"
  admin_password      = "M1cr0s0ft"
  network_interface_ids = [azurerm_network_interface.orch2_interface.id,]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
    "AlwaysPoweredOn" = local.tag_AlwaysPoweredOn
  }
}

#########################################################################
################################SQL SERVER###############################
#########################################################################
resource "azurerm_sql_server" "primary" {
  resource_group_name          = local.resource_group_name
  name                         = "ar-sqlserver-01"
  location                     = local.resource_group_location
  version                      = "12.0"
  administrator_login          = "uipath_sql"
  administrator_login_password = "M1cr0s0ft"

  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
  }
}

resource "azurerm_sql_database" "uipath-db" {
  name                = "UiPath"
  resource_group_name = azurerm_sql_server.primary.resource_group_name
  location            = azurerm_sql_server.primary.location
  server_name         = azurerm_sql_server.primary.name
  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
  }
}

resource "azurerm_sql_database" "insights-db" {
  name                = "Identity"
  resource_group_name = azurerm_sql_server.primary.resource_group_name
  location            = azurerm_sql_server.primary.location
  server_name         = azurerm_sql_server.primary.name
  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
  }
}

resource "azurerm_sql_virtual_network_rule" "primary_sqlvnetrule" {
  name                = "sql-vnet-rule"
  resource_group_name = local.resource_group_name
  server_name         = azurerm_sql_server.primary.name
  subnet_id           = azurerm_subnet.internal.id
}

resource "azurerm_sql_firewall_rule" "primary" {
  name                = "FirewallRule1"
  resource_group_name = local.resource_group_name
  server_name         = azurerm_sql_server.primary.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

#########################################################################
################################HAA NODES################################
#########################################################################


resource "azurerm_network_interface" "haa_master_network_interface" {
  name                = "haa-master-acctni"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "haa-master-node-ip-config"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "dynamic"
  }
  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
    "AlwaysPoweredOn" = local.tag_AlwaysPoweredOn
  }
}

resource "azurerm_network_interface" "haa_slave_network_interface" {
  count = 2
  name                = "haa-slave-acctni-${count.index}"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "haa-slave-node-ip-config-${count.index}"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "dynamic"
  }
  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
    "AlwaysPoweredOn" = local.tag_AlwaysPoweredOn
  }
}

resource "azurerm_linux_virtual_machine" "haa-master-node" {
  name                = "haa-master"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  size                = local.vm_size
  disable_password_authentication = false
  admin_username      = "uipathadmin"
  admin_password      = "M1cr0s0ft"
  network_interface_ids = [azurerm_network_interface.haa_master_network_interface.id,]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "7.8"
    version   = "latest"
  }
  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
    "AlwaysPoweredOn" = local.tag_AlwaysPoweredOn
  }
}

resource "azurerm_linux_virtual_machine" "haa-slave-node" {
  count = 2
  name                = "haa-slave-${count.index}"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  size                = local.vm_size
  disable_password_authentication = false
  admin_username      = "uipathadmin"
  admin_password      = "M1cr0s0ft"
  network_interface_ids = [element(azurerm_network_interface.haa_slave_network_interface.*.id, count.index)]

  #depends_on = [azurerm_linux_virtual_machine.haa-master-node]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "7.8"
    version   = "latest"
  }
  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
    "AlwaysPoweredOn" = local.tag_AlwaysPoweredOn
  }
}

#########################################################################
################################STORAGE###############################
#########################################################################

resource "azurerm_storage_account" "example" {
  name                     = "arorchstorage01"
  resource_group_name      = local.resource_group_name
  location                 = local.resource_group_location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
  }
}

resource "azurerm_storage_share" "example" {
  name                 = "production"
  storage_account_name = azurerm_storage_account.example.name
  quota                = 50
}

resource "azurerm_storage_share_directory" "example" {
  name                 = "orchestrator"
  share_name           = azurerm_storage_share.example.name
  storage_account_name = azurerm_storage_account.example.name
}

#########################################################################
################################NAT GATEWAY###############################
#########################################################################

resource "azurerm_public_ip" "nat_public_ip" {
  name                = "nat-gateway-publicIP"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  #zones               = ["1"]
  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
  }
}

resource "azurerm_public_ip_prefix" "nat_public_ip_prefix" {
  name                = "nat-gateway-publicIPPrefix"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  prefix_length       = 30
  # zones               = ["1"]
  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
  }
}

resource "azurerm_nat_gateway" "nat_gateway" {
  name                = "natgateway"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  public_ip_prefix_ids    = [azurerm_public_ip_prefix.nat_public_ip_prefix.id]
  idle_timeout_in_minutes = 10
  sku_name                = "Standard"
  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
  }
}

resource "azurerm_nat_gateway_public_ip_association" "example" {
  nat_gateway_id       = azurerm_nat_gateway.nat_gateway.id
  public_ip_address_id = azurerm_public_ip.nat_public_ip.id
}

resource "azurerm_subnet_nat_gateway_association" "orchestrator-nat-association" {
  subnet_id      = azurerm_subnet.internal.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateway.id
}

#########################################################################
################################BASTION HOST###############################
#########################################################################


resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_public_ip" "bastion_public_ip" {
  name                = "bastion_public_ip"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
  }
}

resource "azurerm_bastion_host" "bastion-host" {
  name                = "TAM-bastion-host"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_public_ip.id
  }
  tags = {
    "Owner" = local.tag_owner
    "Project" = local.tag_project
  }
}