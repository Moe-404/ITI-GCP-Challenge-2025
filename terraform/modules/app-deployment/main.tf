# Redis deployment
resource "kubernetes_deployment" "redis" {
  metadata {
    name      = "redis"
    namespace = "default"
    labels = {
      app = "redis"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "redis"
      }
    }

    template {
      metadata {
        labels = {
          app = "redis"
        }
      }

      spec {
        container {
          image = "redis:7-alpine"
          name  = "redis"

          port {
            container_port = 6379
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }
}

# Redis service
resource "kubernetes_service" "redis" {
  metadata {
    name      = "redis"
    namespace = "default"
  }

  spec {
    selector = {
      app = kubernetes_deployment.redis.metadata[0].labels.app
    }

    port {
      port        = 6379
      target_port = 6379
    }

    type = "ClusterIP"
  }
}

# Python app deployment
resource "kubernetes_deployment" "python_app" {
  metadata {
    name      = "python-app"
    namespace = "default"
    labels = {
      app = "python-app"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "python-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "python-app"
        }
      }

      spec {
        container {
          image = "${var.artifact_registry_url}/python-app:latest"
          name  = "python-app"

          port {
            container_port = 8080
          }

          env {
            name  = "REDIS_HOST"
            value = "redis"
          }

          env {
            name  = "REDIS_PORT"
            value = "6379"
          }

          env {
            name  = "REDIS_DB"
            value = "0"
          }

          env {
            name  = "ENVIRONMENT"
            value = "production"
          }

          env {
            name  = "PORT"
            value = "8080"
          }

          env {
            name  = "HOST"
            value = "0.0.0.0"
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.redis]
}

# Python app service
resource "kubernetes_service" "python_app" {
  metadata {
    name      = "python-app"
    namespace = "default"
  }

  spec {
    selector = {
      app = kubernetes_deployment.python_app.metadata[0].labels.app
    }

    port {
      port        = 80
      target_port = 8080
    }

    type = "ClusterIP"
  }
}

# Ingress for external access
resource "kubernetes_ingress_v1" "python_app" {
  metadata {
    name      = "python-app-ingress"
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class"                = "gce"
      "kubernetes.io/ingress.global-static-ip-name" = google_compute_global_address.app_ip.name
      "ingress.gcp.kubernetes.io/load-balancer-type" = "External"
    }
  }

  spec {
    rule {
      http {
        path {
          path = "/*"
          backend {
            service {
              name = kubernetes_service.python_app.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.python_app]
}

# Global IP address for the load balancer
resource "google_compute_global_address" "app_ip" {
  name         = "python-app-ip"
  project      = var.project_id
  address_type = "EXTERNAL"
} 