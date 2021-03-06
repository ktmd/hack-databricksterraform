variable group_name {}

provider "azurerm" {
  version = "~> 2.3"
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = var.group_name
  location = "eastus" # note must be lower without spaces not verbose style
}

resource "azurerm_databricks_workspace" "example" {
  name                = "databricks-test"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "standard"
}


resource "shell_script" "pat_token" {
  lifecycle_commands {
    create = "pwsh ${path.module}/scripts/pat.ps1 -type create"
    read   = "pwsh ${path.module}/scripts/pat.ps1 -type read"
    update = "pwsh ${path.module}/scripts/pat.ps1 -type update"
    delete = "pwsh ${path.module}/scripts/pat.ps1 -type delete"
  }

  working_directory = path.module

  environment = {
    pat_token_name  = "tf_pat_token"
    workspace_id    = azurerm_databricks_workspace.example.id
    DATABRICKS_HOST = "https://${azurerm_resource_group.example.location}.azuredatabricks.net"
  }
}

resource "shell_script" "cluster" {
  lifecycle_commands {
    create = "pwsh ${path.module}/scripts/cluster.ps1 -type create"
    read   = "pwsh ${path.module}/scripts/cluster.ps1 -type read"
    update = "pwsh ${path.module}/scripts/cluster.ps1 -type update"
    delete = "pwsh ${path.module}/scripts/cluster.ps1 -type delete"
  }

  working_directory = path.module

  environment = {
    DATABRICKS_HOST  = "https://${azurerm_resource_group.example.location}.azuredatabricks.net"
    DATABRICKS_TOKEN = shell_script.pat_token.output["token_value"]
    wait_for_state   = "PENDING"
    debug_log        = true
    # Enabled passthrough for single user.
    # `jsonencode(jsondecode(x))` ensures invalid json fails during plan stage
    # not midway through a deployment -> fail fast and early if you miss a comma. 
    cluster_json     = jsonencode(jsondecode(<<JSON
      {
        "cluster_name": "my-cluster-t1",
        "spark_version": "6.4.x-scala2.11",
        "node_type_id": "Standard_D3_v2",
        "num_workers": "1",
        "autotermination_minutes": 300
    }
JSON
))
  }
}