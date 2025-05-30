# VPC Network
resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode           = "REGIONAL"
}

# Management Subnet (with NAT gateway)
resource "google_compute_subnetwork" "management" {
  name          = var.management_subnet_name
  ip_cidr_range = var.management_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id

  # Enable private Google access
  private_ip_google_access = true
}

# Restricted Subnet (no internet access)
resource "google_compute_subnetwork" "restricted" {
  name          = var.restricted_subnet_name
  ip_cidr_range = var.restricted_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id

  # Enable private Google access
  private_ip_google_access = true

  # Secondary IP ranges for GKE pods and services
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

# Cloud Router for NAT
resource "google_compute_router" "router" {
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

# NAT Gateway for management subnet
resource "google_compute_router_nat" "nat" {
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.management.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# Firewall rule to allow IAP access to management subnet
resource "google_compute_firewall" "allow_iap" {
  name    = "${var.network_name}-allow-iap"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "3389"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["iap-access"]
}

# Firewall rule to allow internal communication
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.network_name}-allow-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.management_subnet_cidr,
    var.restricted_subnet_cidr,
    var.pods_cidr,
    var.services_cidr
  ]
}

# Firewall rule to deny internet access from restricted subnet
resource "google_compute_firewall" "deny_internet_restricted" {
  name      = "${var.network_name}-deny-internet-restricted"
  network   = google_compute_network.vpc.name
  direction = "EGRESS"
  priority  = 1000

  deny {
    protocol = "all"
  }

  # Block general internet but allow the specific ranges we need
  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["no-internet"]
  
  # This rule is lower priority, so our allow rules above will take precedence
}

# Firewall rule to allow Google APIs access from restricted subnet
resource "google_compute_firewall" "allow_google_apis_restricted" {
  name      = "${var.network_name}-allow-google-apis-restricted"
  network   = google_compute_network.vpc.name
  direction = "EGRESS"
  priority  = 500

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  # Allow access to Google APIs via private.googleapis.com
  destination_ranges = ["199.36.153.8/30"]
  target_tags        = ["no-internet", "gke-node"]
}

# Additional firewall rule for Google APIs (restricted.googleapis.com)
resource "google_compute_firewall" "allow_restricted_google_apis" {
  name      = "${var.network_name}-allow-restricted-google-apis"
  network   = google_compute_network.vpc.name
  direction = "EGRESS"
  priority  = 500

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  # Allow access to restricted.googleapis.com
  destination_ranges = ["199.36.153.4/30"]
  target_tags        = ["no-internet", "gke-node"]
}

# Firewall rule to allow health checks
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${var.network_name}-allow-health-checks"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["allow-health-checks"]
}

# Firewall rule to allow GKE master to nodes communication
resource "google_compute_firewall" "allow_gke_master" {
  name    = "${var.network_name}-allow-gke-master"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["443", "10250", "8080", "9443"]
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["172.16.0.0/28"]  # Master CIDR
  target_tags   = ["gke-node"]
}

# Firewall rule for webhook admission controller
resource "google_compute_firewall" "allow_webhook_admission" {
  name    = "${var.network_name}-allow-webhook-admission"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["8443", "9443", "15017"]
  }

  source_ranges = ["172.16.0.0/28"]  # Master CIDR
  target_tags   = ["gke-node"]
}

# Firewall rule to allow nodes to master communication
resource "google_compute_firewall" "allow_nodes_to_master" {
  name      = "${var.network_name}-allow-nodes-to-master"
  network   = google_compute_network.vpc.name
  direction = "EGRESS"
  priority  = 500

  allow {
    protocol = "tcp"
    ports    = ["443", "6443"]
  }

  destination_ranges = ["172.16.0.0/28"]  # Master CIDR
  target_tags        = ["gke-node"]
}

# Firewall rule to allow node-to-node communication
resource "google_compute_firewall" "allow_node_to_node" {
  name    = "${var.network_name}-allow-node-to-node"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_tags = ["gke-node"]
  target_tags = ["gke-node"]
}

# Firewall rule to allow DNS from nodes
resource "google_compute_firewall" "allow_dns_egress" {
  name      = "${var.network_name}-allow-dns-egress"
  network   = google_compute_network.vpc.name
  direction = "EGRESS"
  priority  = 500

  allow {
    protocol = "tcp"
    ports    = ["53"]
  }

  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  destination_ranges = ["8.8.8.8/32", "8.8.4.4/32", "169.254.169.254/32"]
  target_tags        = ["gke-node"]
} 