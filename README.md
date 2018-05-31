# Kubernetes Blue/Green Deploy on AKS

Tutorial that shows how to execute a [blue/green deployment](https://martinfowler.com/bliki/BlueGreenDeployment.html) within Kubernetes on AKS.

## Prerequisities

All of this can be done by running the following using Azure CLI within Azure Cloud Shell or on your terminal (provided its installed and logged into Azure):.

```bash
# Enable AKS preview
az provider register -n Microsoft.Network
az provider register -n Microsoft.Storage
az provider register -n Microsoft.Compute
az provider register -n Microsoft.ContainerService

# create a resource group
az group create --name k8s-bg-demo --location eastus

# Create AKS cluster with 3 nodes
az aks create --resource-group k8s-bg-demo \
              --name myK8sCluster \
              --node-count 3 \
              --generate-ssh-keys

# Connect to the cluster (ensures you have kubectl installed)
az aks install-cli

# Get credentials from cluster
az aks get-credentials --resource-group k8s-bg-demo \
                       --name myAKSCluster

# Verify connectivity
kubectl get nodes
```

## Setup a "Blue" Deployment

The `Deployment` (`kubernetes/deploy-blue.yaml`) will setup 3 NodeJS Hello World containers with a specific image `name` and `version`. The `Service` will use this later while doing the swtich over to another version.

```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nodejs-hello-world-1.0.0
spec:
  replicas: 3
  template:
    metadata:
      labels:
        name: nodejs-hello-world
        version: "1.0.0"
    spec:
      containers: 
        - name: nodejs-hello-world
          image: richardjortega/nodejs-hello-world:1.0.0
          ports:
            - name: http
              containerPort: 8080
```

Create a new Deployment:

This assumes you have already configured your access to the AKS cluster.

```bash
$ kubectl apply -f kube/deploy-blue.yaml
```

You should see 1 deployment and 3 pods on your Kubernetes cluster (via web ui or kubectl)

Lets now add a `Service` of type `LoadBalancer` which will get an Azure Load Balancer and provide external access to our pods.

```yaml
apiVersion: v1
kind: Service
metadata: 
  name: nodejs-hello-world
  labels: 
    name: nodejs-hello-world
spec:
  ports:
    - name: http
      port: 80
      targetPort: 8080
  selector: 
    name: nodejs-hello-world
    version: "1.0.0"
  type: LoadBalancer
```

Create a new Service:

```bash
$ kubectl apply -f kube/service.yaml
```

### Test external access for blue environment

Find the **EXTERNAL-IP** given to the service via:

```
$ kubectl get svc nodejs-hello-world --watch
```

```
NAME                 TYPE           CLUSTER-IP    EXTERNAL-IP    PORT(S)        AGE
nodejs-hello-world   LoadBalancer   10.0.208.92   40.121.10.48   80:32177/TCP   4m
```

Alternatively, this is available on the dashboard of the Kubernetes cluster web UI using `kube proxy`.

## Update the app

In order to do a blue/green, we'll to entirely stand up another version of the environment. For this, let's create another `Deployment`, then we'll use `Service` to put to that after we've ok'ed it.

### Setup a "Green" Deployment

The new deployment will use the version of the image we'd like to switch to, and the labels we use will reflect that version. Doing so will ensure the `Service` we created won't accidentally start routing requests to this deployment.

Here we have created another file (`kube/deploy-green.yaml`) for convenience. 

```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nodejs-hello-world-2.0.0
spec:
  replicas: 3
  template:
    metadata:
      labels:
        name: nodejs-hello-world
        version: "2.0.0"
    spec:
      containers: 
        - name: nodejs-hello-world
          image: richardjortega/nodejs-hello-world:2.0.0
          ports:
            - name: http
              containerPort: 8080
```

Apply the deployment:

```
$ kubectl apply -f kube/deploy-green.yaml
```

### Change versions and switch traffic

We have created another file (`service-2.0.0.yaml`), however we could've modified the file directly or done it via `sed`, the choice is yours. Kuberentes will do a diff on your updates and apply the changes.

Apply updates to the Service:

```
$ kubectl apply -f kube/service-2.0.0.yaml
```

### Test switched version

Traffic is will now point to the Green version app (which should now show "Hello, Argentina!".

Note that in a production scenario, you may have longer requests being handled, so don't delete Blue until its been fully drained.

Also, keep Blue version up will allow for an easy rollback if necessary.

## Use an internal load balancer with Azure Kubernetes Service (AKS)

Internal load balancing makes a Kubernetes service accessible to applications running in the same virtual network as the Kubernetes cluster. The following will allow you to provide that functionality on AKS using Azure Load Balancer.

### Create internal load balancer

To create an internal load balancer, build a service manifest with the service type `LoadBalancer` and the `azure-load-balancer-internal` annotation as seen in the following sample.

We have created a file called `service-ilb.yaml` which points to the app `nodejs-hello-world`, so now we will have two points of entry: one external LB (previously shown) and now an internal LB.

```yaml
apiVersion: v1
kind: Service
metadata: 
  name: nodejs-hello-world-ilb
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
  labels: 
    name: nodejs-hello-world-ilb
spec:
  ports:
    - name: http
      port: 80
      targetPort: 8080
  selector: 
    name: nodejs-hello-world
    version: "2.0.0"
  type: LoadBalancer
```

Once deployed, an Azure load balancer is created and made available on the same virtual network as the AKS cluster.

![Image of AKS internal load balancer](https://docs.microsoft.com/en-us/azure/aks/media/internal-lb/internal-lb.png)

When retrieving the service details, the IP address in the `EXTERNAL-IP` column is the IP address of the internal load balancer.

```console
$ kubectl get service azure-vote-front --watch

NAME               TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
azure-vote-front   LoadBalancer   10.0.248.59   10.240.0.7    80:30555/TCP   10s
```

Separately, I deployed an Ubuntu VM for testing within the same VNet and here were the results:

```console
# Accessing ELB with external IP:
riortega@ubuntu-k8s-test:~$ curl 40.121.10.48
Hello, Argentina

# Accessing Service via Cluster IP while being in same VNet:
riortega@ubuntu-k8s-test:~$ curl 10.0.24.45
# => Stalls, eventually timeouts

# Accessing Service via ILB using internal IP while in same VNet:
riortega@ubuntu-k8s-test:~$ curl 10.240.0.10:80
Hello, Argentina!
```

If you'd like to specify an IP address for the ILB, you can add a `loadBalancerIP` property to the load balancer spec. Details on that can be found here: [Specify an IP address](https://docs.microsoft.com/en-us/azure/aks/internal-lb#specify-an-ip-address)

## Further readings

- [AKS Networking Overview](https://docs.microsoft.com/en-us/azure/aks/networking-overview)
- [HTTPS Ingress on Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/ingress)