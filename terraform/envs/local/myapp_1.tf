module "myapp_1" {
  source = "../../modules/myapp"

  secret_key = var.myapp_secret_key
  db_password = var.myapp_db_password
  log_level = "debug"
}
