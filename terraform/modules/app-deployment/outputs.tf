output "app_external_ip" {
  description = "External IP address of the application"
  value       = google_compute_global_address.app_ip.address
}

output "redis_service_name" {
  description = "Name of the Redis service"
  value       = kubernetes_service.redis.metadata[0].name
}

output "python_app_service_name" {
  description = "Name of the Python app service"
  value       = kubernetes_service.python_app.metadata[0].name
}

output "ingress_name" {
  description = "Name of the ingress"
  value       = kubernetes_ingress_v1.python_app.metadata[0].name
} 