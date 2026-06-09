output "vm_names" {
  value = [
    libvirt_domain.balancer.name,
    libvirt_domain.frontend1.name,
    libvirt_domain.frontend2.name,
    libvirt_domain.db.name
  ]
}
