variable "name" {
  description = "Name of the Azure resource group. Use the repository naming convention, for example rg-azref-dev-uksouth-001."
  type        = string

  validation {
    condition = (
      var.name == trimspace(var.name) &&
      length(var.name) >= 1 &&
      length(var.name) <= 90
    )
    error_message = "Resource group name must contain 1 to 90 characters and have no leading or trailing whitespace."
  }

  validation {
    condition = (
      can(regex("^[A-Za-z0-9_.()-]+$", var.name)) &&
      !endswith(var.name, ".")
    )
    error_message = "Resource group name may contain only ASCII letters, numbers, underscores, parentheses, hyphens, and periods, and cannot end with a period."
  }
}

variable "location" {
  description = "Azure region for the resource group's metadata, using the canonical region name such as uksouth."
  type        = string

  validation {
    condition = (
      var.location == trimspace(var.location) &&
      length(var.location) > 0
    )
    error_message = "Location must not be empty or contain leading or trailing whitespace."
  }
}

variable "required_tags" {
  description = "Required ownership, environment, cost, and data-classification tags. The module adds managed_by=terraform."
  type = object({
    application         = string
    environment         = string
    owner               = string
    cost_center         = string
    data_classification = string
  })

  validation {
    condition = alltrue([
      for value in values(var.required_tags) : (
        length(trimspace(value)) > 0 &&
        length(value) <= 256
      )
    ])
    error_message = "Every required tag value must be non-empty and contain at most 256 characters."
  }

  validation {
    condition = contains(
      ["dev", "qual", "prod", "shared", "sandbox"],
      var.required_tags.environment
    )
    error_message = "The environment tag must be one of dev, qual, prod, shared, or sandbox."
  }
}

variable "additional_tags" {
  description = "Optional extra tags. Required tags and managed_by are reserved and cannot be overridden."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for key, value in var.additional_tags : (
        length(trimspace(key)) > 0 &&
        length(key) <= 512 &&
        length(regexall("[<>%&\\\\?/]", key)) == 0 &&
        length(trimspace(value)) > 0 &&
        length(value) <= 256
      )
    ])
    error_message = "Additional tag keys and values must be non-empty; keys may contain at most 512 characters, cannot contain <, >, %, &, backslash, ?, or /, and values may contain at most 256 characters."
  }

  validation {
    condition     = length(var.additional_tags) <= 44
    error_message = "At most 44 additional tags are allowed because the module creates six standard tags and Azure resources support at most 50 tags."
  }

  validation {
    condition = length(setintersection(
      toset([for key in keys(var.additional_tags) : lower(key)]),
      toset([
        "application",
        "environment",
        "owner",
        "cost_center",
        "data_classification",
        "managed_by",
      ])
    )) == 0
    error_message = "Additional tags cannot redefine application, environment, owner, cost_center, data_classification, or managed_by."
  }
}
