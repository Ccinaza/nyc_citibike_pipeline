variable "project" {
  description = "My Project "
  default     = "smiling-audio-448313-p0" # update to your project name
}

variable "location" {
  description = "My Project Location"
  default     = "EU"
}

variable "region" {
  description = "My Project region"
  default     = "europe-west1" # update to your own region
}

variable "bq_dataset_name" {
  description = "My BigQuery Dataset Name"
  default     = "nyc_bike_rides" # update to your preferred dataset name
}

variable "gcs_bucket_name" {
  description = "My Storage Bucket Name"
  default     = "naza_nyc_bike_rides" # update to a unique bucket name
}

variable "gcs_storage_class" {
  description = "My Bucket Storage Class"
  default     = "STANDARD"
}

variable "zone" {
  description = "GCP zone for Airflow VM"
  default     = "europe-west1-b"
}
