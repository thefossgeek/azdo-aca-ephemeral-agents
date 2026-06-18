terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.76.0, < 5.0.0"
    }
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = ">= 1.15.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.11.0"
    }
  }
}
