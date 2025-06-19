terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.1-rc8"
    }
  }
}

variable "pm_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "pm_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
}

variable "pm_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
}

variable "sshkeys" {
  description = "SSH public key(s) to inject into the VM"
  type        = string
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

provider "proxmox" {
  pm_api_url         = var.pm_api_url
  pm_tls_insecure    = true
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
}

resource "proxmox_vm_qemu" "qemu-vm" {
  for_each = var.vm_configs

  vmid    = each.value.vm_id
  name    = each.value.name
  vcpus   = each.value.vcpus
  memory  = each.value.memory
  balloon = each.value.memory

  clone       = "t-ubuntu22"
  clone_wait  = 5
  full_clone  = true
  target_node = "arya-pve"

  cpu_type     = "host"
  sockets      = 1
  cores        = 2
  numa         = true
  onboot       = true
  hotplug      = "disk,network,memory,cpu"
  scsihw       = "virtio-scsi-single"

  cipassword   = "ubuntu"
  ciupgrade    = true
  ciuser       = "ubuntu"
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
          storage = "local"
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
          storage   = "local"
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
