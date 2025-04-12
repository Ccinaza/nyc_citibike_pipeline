terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.17.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

# GCS Bucket for raw Citi Bike data
resource "google_storage_bucket" "bike_trips" {
  name          = var.gcs_bucket_name
  location      = var.location
  force_destroy = true

  lifecycle_rule {
    condition { age = 1 }
    action { type = "AbortIncompleteMultipartUpload" }
  }
}

# BigQuery Datasets
resource "google_bigquery_dataset" "nyc_bikes_staging" {
  dataset_id = "nyc_bikes_staging"
  location   = var.location
}

resource "google_bigquery_dataset" "nyc_bikes_prod" {
  dataset_id = "nyc_bikes_prod"
  location   = var.location
}

# VM for Airflow
resource "google_compute_instance" "airflow_vm" {
  name         = "airflow-vm"
  machine_type = "e2-standard-2"
  zone = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 50
    }
  }

  network_interface {
    network = "default"
    access_config {}  # Public IP
  }

  # Startup script with full Airflow + GCP setup
  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y python3-pip python3-dev libpq-dev
    pip3 install apache-airflow==2.6.0 google-cloud-storage google-cloud-bigquery requests
    export AIRFLOW_HOME=/home/airflow
    mkdir -p $AIRFLOW_HOME/dags
    airflow db init
    airflow users create --username admin --password admin --firstname cci --lastname naza --role Admin --email admin@admin.com
    nohup airflow webserver -p 8080 --log-file /opt/nyc-bike-rides-pipeline/logs/webserver.log &  #background webserver
    nohup airflow scheduler --log-file /opt/nyc-bike-rides-pipeline/logs/scheduler.log &   # Background scheduler
    sleep 10
  EOT

  # Service account for GCS/BigQuery access
  service_account {
    email  = "804424983894-compute@developer.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]  # Full GCP access
  }
}

# Firewall for Airflow UI
resource "google_compute_firewall" "airflow_firewall" {
  name    = "allow-airflow-ui"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  # source_ranges = ["102.212.209.30/32"]  # Replace with your IP (e.g., "203.0.113.5/32")
  source_ranges = ["0.0.0.0/0"]
}

# Outputs
output "bucket_name" {
  value = google_storage_bucket.bike_trips.name
}

output "vm_public_ip" {
  value = google_compute_instance.airflow_vm.network_interface[0].access_config[0].nat_ip
}