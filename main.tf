terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.1"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# ============ ПУЛ ============
resource "libvirt_pool" "default" {
  name = "default"
  type = "dir"
  path = "/var/lib/libvirt/images"
}

# ============ СЕТЬ ============
resource "libvirt_network" "web_net" {
  name      = "web-network"
  mode      = "nat"
  domain    = "web.local"
  addresses = ["192.168.200.0/24"]
  dhcp {
    enabled = true
  }
}

# ============ ОБРАЗ ============
resource "libvirt_volume" "ubuntu_image" {
  name   = "ubuntu-22.04-web.img"
  source = "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
  pool   = libvirt_pool.default.name
  format = "qcow2"
}

# ============ ШАБЛОН CLOUD-INIT ============
data "template_file" "user_data" {
  template = file("${path.module}/cloud-init.yaml")
  vars = {
    ssh_key = file("~/.ssh/id_rsa.pub")
  }
}

# ============ BALANCER ============
resource "libvirt_volume" "balancer_disk" {
  name           = "balancer-disk.qcow2"
  base_volume_id = libvirt_volume.ubuntu_image.id
  pool           = libvirt_pool.default.name
  size           = 10737418240
}

resource "libvirt_cloudinit_disk" "balancer_init" {
  name      = "balancer-init.iso"
  pool      = libvirt_pool.default.name
  user_data = data.template_file.user_data.rendered
}

resource "libvirt_domain" "balancer" {
  name   = "balancer"
  memory = 1024
  vcpu   = 1
  cloudinit = libvirt_cloudinit_disk.balancer_init.id
  network_interface {
    network_name = libvirt_network.web_net.name
  }
  disk {
    volume_id = libvirt_volume.balancer_disk.id
  }
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# ============ FRONTEND-1 ============
resource "libvirt_volume" "frontend1_disk" {
  name           = "frontend1-disk.qcow2"
  base_volume_id = libvirt_volume.ubuntu_image.id
  pool           = libvirt_pool.default.name
  size           = 10737418240
}

resource "libvirt_cloudinit_disk" "frontend1_init" {
  name      = "frontend1-init.iso"
  pool      = libvirt_pool.default.name
  user_data = data.template_file.user_data.rendered
}

resource "libvirt_domain" "frontend1" {
  name   = "frontend-1"
  memory = 1024
  vcpu   = 1
  cloudinit = libvirt_cloudinit_disk.frontend1_init.id
  network_interface {
    network_name = libvirt_network.web_net.name
  }
  disk {
    volume_id = libvirt_volume.frontend1_disk.id
  }
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# ============ FRONTEND-2 ============
resource "libvirt_volume" "frontend2_disk" {
  name           = "frontend2-disk.qcow2"
  base_volume_id = libvirt_volume.ubuntu_image.id
  pool           = libvirt_pool.default.name
  size           = 10737418240
}

resource "libvirt_cloudinit_disk" "frontend2_init" {
  name      = "frontend2-init.iso"
  pool      = libvirt_pool.default.name
  user_data = data.template_file.user_data.rendered
}

resource "libvirt_domain" "frontend2" {
  name   = "frontend-2"
  memory = 1024
  vcpu   = 1
  cloudinit = libvirt_cloudinit_disk.frontend2_init.id
  network_interface {
    network_name = libvirt_network.web_net.name
  }
  disk {
    volume_id = libvirt_volume.frontend2_disk.id
  }
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# ============ DATABASE ============
resource "libvirt_volume" "db_disk" {
  name           = "db-disk.qcow2"
  base_volume_id = libvirt_volume.ubuntu_image.id
  pool           = libvirt_pool.default.name
  size           = 10737418240
}

resource "libvirt_cloudinit_disk" "db_init" {
  name      = "db-init.iso"
  pool      = libvirt_pool.default.name
  user_data = data.template_file.user_data.rendered
}

resource "libvirt_domain" "db" {
  name   = "db"
  memory = 1024
  vcpu   = 1
  cloudinit = libvirt_cloudinit_disk.db_init.id
  network_interface {
    network_name = libvirt_network.web_net.name
  }
  disk {
    volume_id = libvirt_volume.db_disk.id
  }
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
