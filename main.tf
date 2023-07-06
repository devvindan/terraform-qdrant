resource "google_compute_network" "vpc_network" {
  name                    = "my-custom-mode-network"
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "default" {
  name          = "my-custom-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-west1"
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_instance" "qdrant" {
  count = 3  # update to the number of instances needed

  name         = "qdrant-vm-${count.index}"
  machine_type = "f1-micro" # need a more powerful machine for larger DB
  zone         = "us-west1-a"
  tags         = ["ssh"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  # Install Docker and run Qdrant
  metadata_startup_script = file("${path.module}/startup_script.sh")

  network_interface {
    subnetwork = google_compute_subnetwork.default.id

    access_config {
      # Include this section to give the VM an external IP address
    }
  }

  metadata = {
    qdrant_bootstrap_uri = count.index == 0 ? "" : "http://${google_compute_instance.qdrant[0].network_interface.0.access_config.0.nat_ip}:6335"
  }
}

resource "google_compute_firewall" "qdrant" {
  name    = "qdrant-app-firewall"
  network = google_compute_network.vpc_network.id

  allow {
    protocol = "tcp"
    ports    = ["6333", "6335"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# add load balancer, etc.