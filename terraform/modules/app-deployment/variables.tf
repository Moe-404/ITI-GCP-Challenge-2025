variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "cluster_location" {
  description = "Location of the GKE cluster"
  type        = string
}

variable "artifact_registry_url" {
  description = "URL of the Artifact Registry repository"
  type        = string
} 