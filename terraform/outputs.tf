output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "The GCP region"
  value       = var.region
}

output "vpc_network_name" {
  description = "Name of the VPC network"
  value       = module.network.network_name
}

output "management_vm_name" {
  description = "Name of the management VM"
  value       = module.compute.vm_name
}

output "management_vm_internal_ip" {
  description = "Internal IP of the management VM"
  value       = module.compute.vm_internal_ip
}

output "gke_cluster_name" {
  description = "Name of the GKE cluster"
  value       = module.gke.cluster_name
}

output "gke_cluster_location" {
  description = "Location of the GKE cluster"
  value       = module.gke.cluster_location
}

output "artifact_registry_url" {
  description = "URL of the Artifact Registry repository"
  value       = module.artifact_registry.repository_url
}

output "application_external_ip" {
  description = "External IP address of the application"
  value       = module.app_deployment.app_external_ip
}

output "gke_service_account_email" {
  description = "Email of the GKE service account"
  value       = module.iam.gke_service_account_email
}

# Instructions for deployment
output "deployment_instructions" {
  description = "Instructions for building and deploying the application"
  value = <<-EOT
    To deploy the application:
    
    1. Connect to the management VM:
       gcloud compute ssh management-vm --zone=${var.zone} --tunnel-through-iap
    
    2. Build and push the Docker image:
       cd /path/to/app
       docker build -t ${module.artifact_registry.repository_url}/python-app:latest .
       docker push ${module.artifact_registry.repository_url}/python-app:latest
    
    3. Connect to the GKE cluster:
       gcloud container clusters get-credentials ${module.gke.cluster_name} --zone=${var.cluster_location}
    
    4. The application will be available at: http://${module.app_deployment.app_external_ip}
  EOT
} 