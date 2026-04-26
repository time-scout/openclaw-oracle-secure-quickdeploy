// Exact snapshot of instance-20260401-1004
// Snapshot date: April 26, 2026

provider "oci" {
  region = "eu-stockholm-1"
}

variable "compartment_id" {
  // OCID of your Compartment/Tenancy
  default = "ocid1.tenancy.oc1..."
}

variable "vcn_id" {
  // Replace with your VCN OCID
  description = "VCN OCID for Security Group"
}

variable "subnet_id" {
  // Replace with your subnet OCID (CIDR 10.0.0.0/24)
  description = "Subnet OCID for 10.0.0.0/24"
}

resource "oci_core_network_security_group" "openclaw_nsg" {
  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
  display_name   = "openclaw_strict_nsg"
}

resource "oci_core_network_security_group_security_rule" "allow_outbound" {
  network_security_group_id = oci_core_network_security_group.openclaw_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

resource "oci_core_network_security_group_security_rule" "allow_ssh_inbound" {
  network_security_group_id = oci_core_network_security_group.openclaw_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_instance" "openclaw_server" {
  availability_domain = "BOfV:EU-STOCKHOLM-1-AD-1"
  compartment_id      = var.compartment_id
  display_name        = "instance-20260401-1004"
  shape               = "VM.Standard.A1.Flex" // ARM64 Architecture
  fault_domain        = "FAULT-DOMAIN-1"

  shape_config {
    ocpus         = 4.0
    memory_in_gbs = 24.0
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = true
    private_ip       = "10.0.0.242"
    nsg_ids          = [oci_core_network_security_group.openclaw_nsg.id]
  }

  source_details {
    source_type = "image"
    // Exact Ubuntu 24.04 aarch64 image currently installed
    source_id   = "ocid1.image.oc1.eu-stockholm-1.aaaaaaaaqqcjpqxy6pw7a2kwxkukzwvxw3q6745oawjtfneax6ldfudtagia"
  }

  metadata = {
    // Insert your public key
    ssh_authorized_keys = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDS+L9vgCtpbdb6ySPU05Z7k1cMD0o12LDFI/schPqGalR7S3zjN0EPMtLOxP2WRvyIb6HyD7K90Qd2ELqRxMY6II2bm4nfNhWUwuxxk8Ot9lBJjGhScjgGtirpQ7qKo0Zt5a9w3tgaHz8S8e0D9nkfVG2PvMR5car77pQjIjd+xk/58PMUTPad3KIvPc7Bjc+0gOID5ck/tKl8u5BX+cWOSaprnHukc3f8xAyIclhuT+bnZcwbzbSlgLhguqxf8u6KsN3WGm7Je6A6yvlo/RzDbq3HHeSVcc+Iq3gGwTFueuLExc/CRcWSRCXC3SlIa1ME35xhg49Xb1mc2/sJ7z2R ssh-key-2026-04-01"
  }
}
