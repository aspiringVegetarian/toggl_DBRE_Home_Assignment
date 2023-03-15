# DBRE Home Assignment
# Author: Martynas Vasiliauskas
# Date: 03/14/23

# Initialize with GCP provider
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

provider "google" {
  # See variables.tf for variable descriptions
  # Modify terraform.tfvars to assign variables
  credentials = var.credentials_file_path
  project     = var.project
  region      = var.region
  zone        = var.zone
}

# Create VPC Network, Subnet, Firewall Rules
resource "google_compute_network" "vpc_network" {
  name = "vpc-network"
}

resource "google_compute_subnetwork" "database_subnet" {
  name          = "database-subnet"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.vpc_network.self_link
}

resource "google_compute_firewall" "allow_internal_traffic" {
  name    = "allow-internal-traffic"
  network = google_compute_network.vpc_network.self_link

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  source_ranges = ["10.0.1.0/24"]
}

# Primary Database
# PostgreSQL instance running on version 12, that will serve as primary (master) server.
# Initialize it with pgbench schema. 
resource "google_compute_instance" "primary_database" {
  name         = "primary-database"
  machine_type = "n1-standard-2"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.database_subnet.self_link
    access_config {
    }
  }

  metadata_startup_script = <<EOF
    #!/bin/bash
    # Install PostgreSQL version 12
    sudo apt update
    sudo apt install postgresql-12 google-cloud-sdk

    # Create a new PostgreSQL user and database
    sudo -u postgres createdb primaryDB

    # Load the pgbench schema into the new database
    sudo -u postgres pgbench -i -s 10 primaryDB

    # Create firewall rule to allow incoming PostgreSQL connections
    gcloud compute firewall-rules create pgsql --allow tcp:5432 --network vpc-network --source-ranges 0.0.0.0/0
    EOF

}

# Standby Database
# PostgreSQL instance that replicates primary database
# Has a daily cron that generates a backup and uploads it to Cloud Storage
resource "google_compute_instance" "standby_database" {
  name         = "standby-database"
  machine_type = "n1-standard-2"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.database_subnet.self_link
    access_config {
    }
  }

  metadata_startup_script = <<EOF
    #!/bin/bash
    # Install PostgreSQL version 12
    sudo apt update
    sudo apt install postgresql-12 google-cloud-sdk
    echo "standby_mode = 'on'" >> /etc/postgresql/12/main/postgresql.conf
    echo "primary_conninfo = 'host=${google_compute_instance.primary_database.network_interface.0.network_ip} port=5432 user=replica password=replica'" >> /etc/postgresql/12/main/postgresql.conf
    sudo -u postgres pg_basebackup -h ${google_compute_instance.primary_database.network_interface.0.network_ip} -D /var/lib/postgresql/12/main -U replica -P
    echo "(0 0 * * *  DATE=$(date +%Y-%m-%d) | pg_dump -Fc -h localhost -U replica pg_basebackup | gzip > "/tmp/pgbackup-$DATE.sql.gz" | gsutil cp "/tmp/pgbackup-$DATE.sql.gz" gs://${google_storage_bucket.daily_backup_storage.name}/pgbackup-$DATE.sql.gz) | crontab -
    EOF
  depends_on              = [google_compute_instance.primary_database]

}

# Cloud Storage
# Contains daily backups. 
# !! Backups are automatically DELETED AFTER 15 DAY retention period !!
resource "google_storage_bucket" "daily_backup_storage" {
  name          = "daily-backup-storage"
  location      = var.region
  force_destroy = false # This ensures that the bucket is not accidentally deleted.

  lifecycle_rule {
    condition {
      age = 16 # Minimum age of 16 days for delete action to occur
    }
    action {
      type = "Delete"
    }
  }

  retention_policy {
    # Retention time in SECONDS
    # 24 hours * 60 mins * 60 seconds = 86400 seconds/day
    retention_period = 15 * 86400 # Retain for 15 days
  }

}

# Monitoring
# ALERT! When CPU Usage > 90% on Primary Database.
resource "google_monitoring_alert_policy" "primary_database_cpu_usage_alert" {
  display_name = "Primary Database CPU Usage >90%"
  combiner     = "OR"

  conditions {
    display_name = "CPU Usage over 90%"
    condition_threshold {
      filter          = "metric.type=\"agent.googleapis.com/cpu/usage_time\" resource.type=\"gce_instance\" resource.label.\"instance_id\"=\"google_compute_instance.primary_database.id\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 90.0
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }
}

# Monitoring
# ALERT! When Disk Usage > 85% on Primary Database.
resource "google_monitoring_alert_policy" "primary_database_disk_usage_alert" {
  display_name = "Primary Database Disk Usage >85%"
  combiner     = "OR"
  conditions {
    display_name = "Disk Usage over 85%"
    condition_threshold {
      filter          = "metric.type=\"agent.googleapis.com/disk/percent_used\" resource.type=\"gce_instance\" resource.label.\"instance_id\"=\"google_compute_instance.primary_database.id\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 85.0
    }
  }
}
