terraform {
  required_version = ">= 1.8, < 2.0"
  required_providers {
    fabric = {
      source  = "microsoft/fabric"
      version = "1.6.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.40"
    }
  }
}

# Configure the Microsoft Fabric Terraform Provider
provider "fabric" {
  # Configuration options

  preview = true
}

provider "azuread" {
  
}

variable "workspace_display_name" {
  description = "A name for the getting started workspace."
  type        = string
}

variable "capacity_name" {
  description = "The name of the capacity to use."
  type = string
}

variable "group_id" {
  description = "The EntraAD Group ID of the group to assign as workspace users."
  type        = string
  default     = "30d11c0d-67f6-424c-bc01-4b784797c6ae"
}

data "fabric_capacity" "main" {
  display_name = var.capacity_name

  lifecycle {
    postcondition {
      condition     = self.state == "Active"
      error_message = "Fabric Capacity is not in Active state. Please check the Fabric Capacity status."
    }
  }
}

resource "fabric_workspace" "main" {
  capacity_id  = data.fabric_capacity.main.id
  display_name = "ws_${var.workspace_display_name}"
  description  = "A workspace for getting started with Microsoft Fabric. Created by Terraform."
  identity = {
    type = "SystemAssigned"
  }
}

resource "fabric_workspace_role_assignment" "owner" {
  workspace_id = fabric_workspace.main.id
  principal    = {
    type = "Group"
    id   = var.group_id
  }
  role = "Contributor"
}

resource "fabric_lakehouse" "gold" {
  workspace_id = fabric_workspace.main.id
  display_name = "lh_${var.workspace_display_name}_gold"
  description  = "A lakehouse for gold (enriched) data. Created by Terraform."
}

resource "fabric_lakehouse" "silver" {
  workspace_id = fabric_workspace.main.id
  display_name = "lh_${var.workspace_display_name}_silver"
  description  = "A lakehouse for silver (aggregated) data. Created by Terraform."
}

resource "fabric_lakehouse" "bronze" {
  workspace_id = fabric_workspace.main.id
  display_name = "lh_${var.workspace_display_name}_bronze"
  description  = "A lakehouse for bronze (raw) data. Created by Terraform."
}

resource "fabric_sql_database" "main" {
  workspace_id = fabric_workspace.main.id
  display_name = "db_${var.workspace_display_name}_main"
  description  = "A SQL database for getting started with Microsoft Fabric. Created by Terraform."
}

output "connection_string_gold" {
  value = fabric_lakehouse.gold.properties.sql_endpoint_properties.connection_string
}

output "connection_string_silver" {
  value = fabric_lakehouse.silver.properties.sql_endpoint_properties.connection_string
}

output "connection_string_bronze" {
  value = fabric_lakehouse.bronze.properties.sql_endpoint_properties.connection_string
}

output "workspace_id" {
  value = fabric_workspace.main.id
}

output "workspace_name" {
  value = fabric_workspace.main.display_name
}

output "sql_connection_string" {
  value = fabric_sql_database.main.properties.connection_string
}