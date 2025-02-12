variable "secret_key" {
  type = string
}

variable "db_password" {
  type = string
}

variable "api_base_url" {
  type = string
  default = "/"
}

variable "log_level" {
  type = string
  default = "error"
}

variable "max_connections" {
  type = string
  default = "50"
}
