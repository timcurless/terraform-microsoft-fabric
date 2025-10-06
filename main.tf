terraform {
  required_version = ">= 1.8, < 2.0"
  required_providers {
    fabric = {
      source  = "microsoft/fabric"
      version = "1.6.0"
    }
  }
}

# Configure the Microsoft Fabric Terraform Provider
provider "fabric" {
  # Configuration options
  preview = false
}

variable "workspace_display_name" {
  description = "A name for the getting started workspace."
  type        = string
}

variable "capacity_name" {
  description = "The name of the capacity to use."
  type = string
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
  display_name = "ws-${var.workspace_display_name}"
}