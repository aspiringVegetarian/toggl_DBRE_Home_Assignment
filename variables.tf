variable "project" {
  description = "The project ID to host the database in."
  type        = string
}

variable "credentials_file_path" {
  description = "Full file path to your .json key"
  type        = string
}

variable "region" {
  description = "The region to host the database in."
  type        = string
  default     = "europe-west4"
}

variable "zone" {
  description = "The zone to host the database in."
  type        = string
  default     = "europe-west4-a"
}