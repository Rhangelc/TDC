//Substitua por seus dados
provider "oci" {
  tenancy_ocid     = ""
  user_ocid        = ""
  fingerprint      = ""
  private_key_path = ""
  region           = ""
}

variable "compartment_ocid" {
  description = "OCID do compartimento (compartment) da Oracle Cloud Infrastructure"
  type        = string
  default     = ""
}


# VCN (Virtual Cloud Network)
resource "oci_core_vcn" "tdc_vcn" {
  cidr_block     = "172.16.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = "tdc_vcn"
}

# Subnet Pública
resource "oci_core_subnet" "tdc_public_subnet" {
  cidr_block          = "172.16.0.0/24"
  display_name        = "tdc_public_subnet"
  compartment_id      = var.compartment_ocid
  vcn_id              = oci_core_vcn.tdc_vcn.id
  prohibit_public_ip_on_vnic = false
  security_list_ids   = [oci_core_security_list.tdc_sl.id]
  route_table_id      = oci_core_route_table.tdc_public_rt.id
}

# Subnet Privada
resource "oci_core_subnet" "tdc_private_subnet" {

  cidr_block          = "172.16.1.0/24"
  display_name        = "tdc_private_subnet"
  compartment_id      = var.compartment_ocid
  vcn_id              = oci_core_vcn.tdc_vcn.id
  prohibit_public_ip_on_vnic = true
  security_list_ids   = [oci_core_security_list.tdc_sl.id]
  route_table_id      = oci_core_route_table.tdc_private_rt.id
}

# Security List
resource "oci_core_security_list" "tdc_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.tdc_vcn.id
  display_name   = "tdc_sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "6"
  }

  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "6"
    tcp_options {
      max = 22
      min = 22
    }
  }
}

# Internet Gateway
resource "oci_core_internet_gateway" "tdc_igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.tdc_vcn.id
  display_name   = "tdc_igw"
}

# NAT Gateway
//resource "oci_core_nat_gateway" "tdc_nat_gw" {
// compartment_id = var.compartment_ocid
//  vcn_id         = oci_core_vcn.tdc_vcn.id
//  display_name   = "tdc_nat_gw"
//}

# Route Table para Subnet Pública
resource "oci_core_route_table" "tdc_public_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.tdc_vcn.id
  display_name   = "tdc_public_rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.tdc_igw.id
  }
}

# Route Table para Subnet Privada
resource "oci_core_route_table" "tdc_private_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.tdc_vcn.id
  display_name   = "tdc_private_rt"

  route_rules {
    destination       = "0.0.0.0/0"
    //network_entity_id = oci_core_nat_gateway.tdc_nat_gw.id
    network_entity_id = oci_core_internet_gateway.tdc_igw.id //temp
  }
}

resource "oci_core_instance" "tdc_erp" {
  availability_domain = "tdsk:SA-SAOPAULO-1-AD-1"
  compartment_id      = var.compartment_ocid
  display_name        = "tdc_erp"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = oci_core_subnet.tdc_public_subnet.id
    display_name     = "primary-nic"
    assign_public_ip = "true"
  }

  source_details {
    source_type = "image"
    source_id   = "ocid1.image.oc1.sa-saopaulo-1.aaaaaaaa5sosu2p5am3wrlhorirpczba3rpxb3dnyjz3xjh6dhc2zwopbwvq"
  }

  metadata = {
    ssh_authorized_keys = ""
  }
}
