# mt-assignment

## Using the Setup
Make sure Docker and Minikube are installed on the local machine. Also `kubectl` and `terraform` cli tools are needed for using this setup.

(1) Check out `minikube` status, and the configured `kubeconfig` context.
```console
$ minikube status
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured

$ kubectl config get-contexts
CURRENT   NAME      CLUSTER    AUTHINFO  NAMESPACE
*         minikube  minikube   minikube  default
```

(2) Clone this respository, initialise terraform in the right directory, and apply the changes by providing the required input:
```console
$ git clone https://github.com/rmin/mt-assignment.git
$ cd mt-assignment/terraform/envs/local
$ terraform init
Initializing the backend...
Initializing modules...
- myapp_1 in ../../modules/myapp
Initializing provider plugins...
- Finding hashicorp/helm versions matching "2.17.0"...
- Finding hashicorp/kubernetes versions matching "2.35.1"...
...
Terraform has been successfully initialized!

$ terraform apply
var.myapp_db_password
  Database Password for MyApp
  Enter a value: 

var.myapp_secret_key
  Secret Key for MyApp
  Enter a value: 

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following
symbols:
  + create
Terraform will perform the following actions:
  # module.myapp_1.helm_release.myapp will be created
  + resource "helm_release" "myapp" {
      + atomic                     = false
      + chart                      = "../../../charts/myapp"
      + cleanup_on_fail            = false
      + create_namespace           = true
      + dependency_update          = false
      ...
      + set {
          # At least one attribute in this block is (or was) sensitive,
          # so its contents will not be displayed.
        }
      ...
    }
Plan: 1 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.
  Enter a value: yes
module.myapp_1.helm_release.myapp: Creating...
module.myapp_1.helm_release.myapp: Creation complete after 2s [id=myapp]
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

(3) We can find the deployed application on Minikube, and run port-forward to access it:
```console
$ export POD_NAME=$(kubectl get pods -l "app.kubernetes.io/name=myapp" -o jsonpath="{.items[0].metadata.name}")
$ export CONTAINER_PORT=$(kubectl get pod $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
$ kubectl port-forward $POD_NAME 8080:$CONTAINER_PORT
Forwarding from 127.0.0.1:8080 -> 5000
```

(4) Visit `http://127.0.0.1:8080` on your browser to use the application. Or, on another terminal call the app with the `curl` cli tool:
```console
$ curl http://127.0.0.1:8080/config
{"API_BASE_URL":"/","DB_PASSWORD":"passw0rdXyZ","LOG_LEVEL":"debug","MAX_CONNECTIONS":"50","SECRET_KEY":"Secr3tXyz","message":"Config and secrets accessed"}
```

## The Application
Under `apps/myapp` folder, a `Dockerfile` can be found, which uses `python:3.13` base Docker image. Required Python packages are freezed to a specific version in the `requirements.txt` file.

The image was built and pushed into the public `Dockerhub` registry under `rmin/mt-myapp` image name and `1.0.0` tag.

A new `healthz` endpoint was added to be used as healthcheck endpoint for K8s.
```
# health-check route
@app.route("/healthz")
def healthz():
    return jsonify({"status": "ok"})
```

### Possible Improvements
(1) To reduce the attack surface, `distroless` base image can be used for production deployments.

(2) A production grade Python application server (e.g. gunicorn) should be used.

(3) Static security tests (SAST) should be applied on the code, 3rd party packages and the base image, as part of the CI pipeline before pushing the final Docker image into the registry.

## The Helm Chart
`helm create` command was used to create the base chart.

To add the required environment variables and secrets, `templates/configmap.yaml` and `templates/secret.yaml` files were also added, and related sections were added to the `values.yaml` file, to include the configurations in the `Deployment` and set some default values for the configs:
```yaml
config:
  SECRET_KEY: ""
  DB_PASSWORD: ""
  API_BASE_URL: "/"
  LOG_LEVEL: "error"
  MAX_CONNECTIONS: "30"
...
envFrom:
  - configMapRef:
      name: myapp
  - secretRef: 
      name: myapp
...
```

`liveness` and `readiness` probes both are using the `/healthz` application endpoint.

The helm chart can be installed using the `helm` cli tool if needed:
```console
$ helm install --set config.SECRET_KEY=xyz --set config.DB_PASSWORD=p123 myapp ./charts/myapp
NAME: myapp
NAMESPACE: default
STATUS: deployed
REVISION: 1
```

### Possible Improvements
(1) `Ingress` and `HorizontalPodAutoscaler` resources was added to the chart but not enabled. In a production environment they should be enabled. A metrics server is required to enabled HPA in the K8s cluster. And an Ingress service such as `ingress-nginx` is also required on the K8s cluster.

(2) The chart should be pushed to, and later consumed from a Helm Chart Repository, in a production environment.

(3) For high-availibility the minimimum `replicaCount` should be 2, and `autoscaling` (HPA) should be enabled.

(4) Ideally `liveness` and `readiness` Probes should use different endpoints (and possible `startup` Probe). `readiness` Probes determine when a container is ready to start accepting traffic (DB, Cache, etc. are ready too).

## Terraform Setup
Directory tree for the `terraform/` setup:
```
envs/
  local/
    versions.tf  # required terraform providers and their freezed versions
    provider.tf  # help provider and it's default configs
    variables.tf  # variables that can be set via CI/CD or cli
    myapp_1.tf  # myapp module instance for this terraform env
    
modules/
  myapp/
    input.tf  # required and optional input config for the module
    myapp.tf  # helm_release resource definition
```
`myapp` module can be reused on the same terraform `env` or new environments.

One `local` env is available, new envs with their own Kubernetes connections and their own `myapp` module instances can be added with different values for the variables.

On a CI/CD setup, the sensitive Secret values `myapp_secret_key` and `myapp_db_password` should be stored in a secure location (provided by the CI/CD platform or a Secret Storage such as Hashicorp Vault) and retrived/injected into the pipeline environment before running the `terraform apply`.

Although by marking these variables as `sensitive = true` Terraform masks these values on its own outputs, it is important to prevent leaking of these secrets into the CI/CD pipeline logs too.

### Possible Improvements
(1) `myapp` module is using the local `../../../charts/myapp` chart. In a production setup, the chart should be hosted on a Chart Repository.

(2) In a production setup, teams should use a pipeline, such as Terraform Cloud or Github Actions, instead of running terraform cli, and hosting local terraform state files.

(3) Using helm provider with terraform may be considered an anti-pattern, since both Terraform, and Kubernetes are implementations of declarative Infra-as-Code. Helm cli tool can directly be used in a CD job too, and the K8s controller makes sure the actual state of the cluster matches the desired state in the final K8s resources generated by the rendered helm chart.

(4) We should keep in mind that, adding core infrastructure IaC (e.g. EKS config), and application IaC in the same terraform setup / repository can be considered an anti-pattern. The velocity of application changes are usually much higher than infra component changes. Each change in an application and running `terraform plan/apply` will go over, and try to discover all the changes in the infra, which is a waste of time and resources.

## AWS Related Considerations
### Networking
Private networking should be used as much as possible for all AWS services. As an example, a VPC (Regional resource) can be deployed with 3 private subnets (1 on each Availibility Zone), to be used by the EKS cluster, and all the Databases (e.g. RDS) or chaching servers (e.g. Elasticache) can also use one or more of the same private subnets.

A Nat Gateway can provide the internet connection for the out-going connections, and proper security measure, such as Security Groups should also be implemented.

For in-coming connections from the Internet, an Application LoadBalancer (and AFW), or Network LoadBalancer (with CloudFront CDN in front of them if needed) can be used in front of the EKS Ingress.

### Access To AWS Services
The Security Group setup of the EKS worker nodes should allow outgoing traffic to the needed AWS services (AWS Security Groups can be assigned directly to PODs as well to allow only specific PODs to access AWS services).

For Authentication we can use AWS IAM Roles for the K8s Service Account that the POD is using. If "portability" to other Cloud providers is a requirement, user/password authentication (e.g. to RDS) can be used (saved in a K8s Secret).
