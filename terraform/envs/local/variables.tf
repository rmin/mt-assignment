variable "myapp_secret_key" {
  description = "Secret Key for MyApp"
  sensitive = true
}

variable "myapp_db_password" {
  description = "Database Password for MyApp"
  sensitive = true
}
