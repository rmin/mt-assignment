resource "helm_release" "myapp" {
  name = "myapp"
  chart = "../../../charts/myapp"
  namespace = "default"
  create_namespace = true
  version = "0.1.0"

  set {
    name  = "config.SECRET_KEY"
    value = var.secret_key
  }
  set {
    name  = "config.DB_PASSWORD"
    value = var.db_password
  }
  set {
    name  = "config.API_BASE_URL"
    value = var.api_base_url
  }
  set {
    name  = "config.LOG_LEVEL"
    value = var.log_level
  }
  set {
    name  = "config.MAX_CONNECTIONS"
    value = var.max_connections
  }
}
