variable "kube_path" {default = "~/.kube/config"}
variable "kube_context" {default = "minikube"}

provider "helm" {
  kubernetes {
    config_path = var.kube_path
    config_context = var.kube_context
  }
}
