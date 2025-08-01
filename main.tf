terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.1-rc8"
    }
  }
}

# Add variable for PM API URL
variable "pm_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://10.10.10.141:8006/api2/json"
}

# Add variables for Proxmox API credentials
variable "pm_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
  sensitive   = true
}

variable "pm_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

# Add variable for SSH keys
variable "sshkeys" {
  description = "SSH public keys for VM access"
  type        = string
  default     = ""
}

# Add variable for cluster name
variable "cluster_name" {
  description = "Proxmox cluster/node name"
  type        = string
  default     = "pve"
}

# Add variable for storage backend
variable "storage_backend" {
  description = "Proxmox storage backend for VM disks"
  type        = string
  default     = "local"
}

provider "proxmox" {
  pm_api_url         = var.pm_api_url
  pm_tls_insecure    = true
  # Use environment variables for secrets:
  # export PM_API_TOKEN_ID="your-user@pve!your-token-name"
  # export PM_API_TOKEN_SECRET="your-token-secret"
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
}

variable "vm_configs" {
  type = map(object({
    vm_id     = number
    name      = string
    vcpus     = number
    memory    = number
    disk_size = string
    bridge    = string
    ip        = string
    gateway   = string
  }))
}

# New variables for template, username, and password
variable "template_name" {
  description = "Name of the template to clone from"
  type        = string
  default     = "t-ubuntu22"
}

variable "vm_username" {
  description = "Username for the VM"
  type        = string
  default     = "ubuntu"
}

variable "vm_password" {
  description = "Password for the VM"
  type        = string
  default     = "ubuntu"
}

resource "proxmox_vm_qemu" "qemu-vm" {
  for_each = var.vm_configs

  vmid    = each.value.vm_id
  name    = each.value.name
  vcpus   = each.value.vcpus
  memory  = each.value.memory
  balloon = each.value.memory
  
  # Clone Template - now using variable
  clone       = var.template_name
  clone_wait  = 5
  full_clone  = true
  target_node = var.cluster_name

  # Default Options
  cpu_type     = "host"
  sockets      = 1
  cores        = 2
  numa         = true
  onboot       = true
  hotplug      = "disk,network,memory,cpu"
  scsihw       = "virtio-scsi-single"

  # Cloud-init Configuration - now using variables
  cipassword   = var.vm_password
  ciupgrade    = true
  ciuser       = var.vm_username
  nameserver   = "8.8.8.8"
  searchdomain = "localhost"
  sshkeys      = var.sshkeys
  
  ipconfig0 = "ip=${each.value.ip},gw=${each.value.gateway}"

  # Add serial port for cloud-init and console access
  serial {
    id   = 0
    type = "socket"
  }

  disks {
    # Cloud-init drive (ide2 is standard for Proxmox)
    ide {
      ide2 {
        cloudinit {
          storage = var.storage_backend
        }
      }
    }
    virtio {
      virtio0 {
        disk {
          size      = each.value.disk_size
          backup    = true
          format    = "raw"
          iothread  = true
          replicate = true
          storage   = var.storage_backend
        }
      }
    }
  }

  network {
    bridge    = each.value.bridge
    firewall  = false
    id        = 0
    link_down = false
    model     = "virtio"
  }
}
