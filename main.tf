terraform {
  required_version = ">= 1.8, < 2.0"
  required_providers {
    fabric = {
      source  = "microsoft/fabric"
      version = "1.6.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

# Configure the Microsoft Fabric Terraform Provider
provider "fabric" {
  # Configuration options
  preview    = true
}

provider "github" {
  owner = var.destination_org
  token = var.gh_token
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

variable "destination_org" {
  description = "The name of the organization in Github that will contain the templated repo."
  default     = "timcurless"
}

variable "gh_token" {
  description = "Github token with permissions to create and delete repos."
  sensitive   = true
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

resource "github_repository" "gh_repo" {
  name       = var.workspace_display_name
  visibility = "public"
  auto_init = true

  # template {
  #   repository = "fabric-template"
  #   owner      = var.destination_org
  #   include_all_branches = true
  # }
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

resource "fabric_workspace_git" "github" {
  workspace_id            = fabric_workspace.main.id
  initialization_strategy = "PreferWorkspace"
  git_provider_details = {
    git_provider_type = "GitHub"
    owner_name        = var.destination_org
    repository_name   = github_repository.gh_repo.name
    branch_name       = "main"
    directory_name    = "/"
  }
  git_credentials = {
    source        = "ConfiguredConnection"
    connection_id = "1d7423b0-dd60-46ae-b436-8231b66153bb"
  }
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