variable "connection" {
  type      = map(any)
  sensitive = true
}

variable "vm_id" {
  type    = number
  default = null
}

variable "container" {
  type    = any
  default = null
}

variable "config" {
  type = map(list(string))
}

locals {
  vm_id             = var.vm_id != null ? var.vm_id : var.container.vm_id
  depends_container = var.container != null ? [var.container] : []
  config = flatten([for key, values in var.config :
    [for value in values : "${key} '${value}'"]
  ])
}

resource "terraform_data" "config" {
  depends_on = [
    local.depends_container,
  ]

  triggers_replace = {
    container = var.container != null ? var.container.id : tostring(local.vm_id)
    config    = var.config
  }

  connection {
    type     = coalesce(var.connection["type"], "ssh")
    user     = coalesce(var.connection["user"], "root")
    password = var.connection["password"]
    host     = var.connection["host"]
    port     = coalesce(var.connection["port"], 22)
  }

  provisioner "remote-exec" {
    inline = [
      "ct-config ${local.vm_id} ${join(" ", local.config)}",
    ]
  }
}
