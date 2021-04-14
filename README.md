# Deploying Kubeflow with ArgoCD

This repository contains Kustomize manifests that point to the upstream
manifest of each Kubeflow component and provides an easy way for people
to change their deployment according to their need. ArgoCD application
manifests for each componenet will be used to deploy Kubeflow. The intended
usage is for people to fork this repository, make their desired kustomizations,
run a script to change the ArgoCD application specs to point to their fork
of this repository, and finally apply a master ArgoCD application that will
deploy all other applications.

To run the below script [yq](https://github.com/mikefarah/yq) version 4
must be installed

Overview of the steps:

- fork this repo
- modify the kustomizations for your purpose
- run `./setup_repo.sh <your_repo_fork_url>`
- commit and push your changes
- run `kubectl apply -f kubeflow.yaml`

## Folder setup

- [argocd](./argocd): Kustomize files for ArgoCD
- [argocd-applications](./argocd-applications): ArgoCD application for each Kubeflow component
- [cert-manager](./cert-manager): Kustomize files for installing cert-manager v1.2
- [kubeflow](./kubeflow): Kustomize files for installing Kubeflow componenets
  - [common/dex-istio](./kubeflow/common/dex-istio): Kustomize files for Dex auth installation
  - [common/oidc-authservice](./kubeflow/common/oidc-authservice): Kustomize files for OIDC authservice
  - [roles-namespaces](./kubeflow/common/roles-namespaces): Kustomize files for Kubeflow namespace and ClusterRoles
  - [user-namespace](./kubeflow/common/user-namespace): Kustomize manifest to create the profile and namespace for the default Kubeflow user
  - [katib](./kubeflow/katib): Kustomize files for installing Katib
  - [kfserving](./kubeflow/kfserving): Kustomize files for installing KFServing
    - [knative](./kubeflow/knative): Kustomize files for installing KNative
  - [central-dashboard](./kubeflow/notebooks/central-dashboard): Kustomize files for installing the Central Dashboard
  - [jupyter-web-app](./kubeflow/notebooks/jupyter-web-app): Kustomize files for installing the Jupyter Web App
    - [notebook-controller](./kubeflow/notebooks/notebook-controller): Kustomize files for installing the Notebook Controller
  - [pod-defaults](./kubeflow/notebooks/pod-defaults): Kustomize files for installing Pod Defaults (a.k.a. admission webhook)
  - [profile-controller_access-management](./kubeflow/notebooks/profile-controller_access-management): Kustomize files for installing the Profile Controller and Access Management
  - [tensorboards-web-app](./kubeflow/notebooks/tensorboards-web-app): Kustomize files for installing the Tensorboards Web App
    - [tensorboard-controller](./kubeflow/notebooks/tensorboard-controller): Kustomize files for installing the Tensorboard Controller
  - [volumes-web-app](./kubeflow/notebooks/volumes-web-app): Kustomize files for installing the Volumes Web App
  - [operators](./kubeflow/operators): Kustomize files for installing the various operators
  - [pipelines](./kubeflow/pipelines): Kustomize files for installing Kubeflow Pipelines
- [metallb](./metallb): Kustomize files for installing MetalLB

### Root files

- [kustomization.yaml](./kustomization.yaml): Kustomization file that references the ArgoCD application files in [argocd-applications](./argocd-applications)
- [kubeflow.yaml](./kubeflow.yaml): ArgoCD application that deploys the ArgoCD applications referenced in [kustomization.yaml](./kustomization.yaml)

## Prerequisite

- kubectl (latest)
- kustomize 4.0.5
- docker (if using kind)

## Quick Start using kind

### Install kind

On linux:

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.10.0/kind-linux-amd64
chmod +x ./kind
mv ./kind /<some-dir-in-your-PATH>/kind
```

On Mac:

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.10.0/kind-darwin-amd64
chmod +x ./kind
mv ./kind /<some-dir-in-your-PATH>/kind
```

On Windows:

```cmd
curl.exe -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v0.10.0/kind-windows-amd64
Move-Item .\kind-windows-amd64.exe c:\some-dir-in-your-PATH\kind.exe
```

### Deploy kind cluster

Note - This will overwrite any existing ~/.kube/config file
Please back up your current file if it already exists

`kind create cluster --config kind/kind-cluster.yaml`

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml
kubectl patch deployment metrics-server -n kube-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"metrics-server","args":["--cert-dir=/tmp", "--secure-port=4443", "--kubelet-insecure-tls","--kubelet-preferred-address-types=InternalIP"]}]}}}}'
```

### Deploy MetalLB

Edit the IP range in [configmap.yaml](./metallb/configmap.yaml) so that it is within
the range of your docker network. To get your docker network range,
run the following command:

`docker network inspect -f '{{.IPAM.Config}}' kind`

After updating the metallb configmap, deploy it by running:

`kustomize build metallb/ | kubectl apply -f -`

### Deploy Argo CD

Deploy Argo CD with the following commaind:

`kustomize build argocd/ | kubectl apply -f -`

Expose Argo CD with a LoadBalancer to access the UI by executing:

`kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'`

Get the IP of the Argo CD endpoint:

`kubectl get svc argocd-server -n argocd`

Login with the username `admin` and the output of the following command as the password:

`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

### Deploy kubeflow

To deploy Kubeflow, execute the following command:

`kubectl apply -f kubeflow.yaml`

Note - This deploys all components of Kubeflow 1.3, it might take a while
for everything to get started. Also, it is unknown what hardware specifications
are needed for this at the current time, so your mileage may vary. Also,
this deployment is using the manifests in this repository directly. For instructions
how to customize the deployment and have Argo CD use those manifests see the next section.

Get the IP of the Kubeflow gateway with the following command:

`kubectl get svc istio-ingressgateway -n istio-system`

Login to Kubeflow with "email-address" `user` and password `12341234`

### Remove kind cluster

Run: `kind delete cluster`

## Installing ArgoCD

For this installation the HA version of ArgoCD is used.
Due to Pod Tolerations, 3 nodes will be required for this installation.
If you do not wish to use a HA installation of ArgoCD,
edit this [kustomization.yaml](./argocd/kustomization.yaml) and remove `/ha`
from the URI.

1. Next, to install ArgoCD execute the following command:

    ```bash
    kustomize build argocd/ | kubectl apply -f -
    ```

2. Install the ArgoCD CLI tool from  [here](https://github.com/argoproj/argo-cd/releases/latest)
3. Access the ArgoCD UI by exposing it through a LoadBalander, Ingress or by port-fowarding
using `kubectl port-forward svc/argocd-server -n argocd 8080:443`
4. Login to the ArgoCD CLI. First get the default password for the `admin` user:
    `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

    Next, login with the following command:
    `argocd login <ARGOCD_SERVER>  # e.g. localhost:8080 or argocd.example.com`

    Finally, update the account password with:
    `argocd account update-password`
5. You can now login to the ArgoCD UI with your new password.
This UI will be handy to keep track of the created resources
while deploying Kubeflow.

Note - Argo CD needs to be able access your repository to deploy applications.
 If the fork of this repository that you are planning to use with Argo CD is private
 you will need to add credentials so it can access the repository. Please see
 the instructions provided by Argo CD [here](https://argoproj.github.io/argo-cd/user-guide/private-repositories/).

## Installing Kubeflow

The purpose of this repository is to make it easy for people to customize their Kubeflow
deployment and have it managed through a GitOps tool like ArgoCD.
First, fork this repository and clone your fork locally.
Next, apply any customization you require in the kustomize folders of the Kubeflow
applications. Next will follow a set of recommended changes that we encourage everybody
to make.

### Credentials

The default `username`, `password` and `namespace` of this deployment are:
`user`, `12341234` and `kubeflow-user` respectively.
To change these, edit the `user` and `profile-name`
(the namespace for this user) in [params.env](./kubeflow/common/user-namespace/params.env).

Next, in [configmap-path.yaml](./kubeflow/common/dex-istio/configmap-patch.yaml)
under `staticPasswords`, change the `email`, the `hash` and the `username`
for your used account.

```yaml
staticPasswords:
- email: user
  hash: $2y$12$4K/VkmDd1q1Orb3xAt82zu8gk7Ad6ReFR4LCP9UeYE90NLiN9Df72
  username: user
```

The `hash` is the bcrypt has of your password.
You can generate this using [this website](https://passwordhashing.com/BCrypt),
or with the command below:

```bash
python3 -c 'from passlib.hash import bcrypt; import getpass; print(bcrypt.using(rounds=12, ident="2y").hash(getpass.getpass()))'
```

To add new static users to Dex, you can add entries to the
[configmap-path.yaml](./kubeflow/common/dex-istio/configmap-patch.yaml)
and set a password as described above.If you have already deployed Kubeflow
commit these changes to your fork so Argo CD detects them. You will also
need to kill the Dex pod or restart the dex deployment. This can be
done in the Argo CD UI, or by running the following command:

```bash
kubectl rollout restart deployment dex -n auth
```

### Ingress and Certificate

By default the Istio Ingress Gateway is setup to use a LoadBalancer
and to redirect HTTP traffic to HTTPS. Manifests for MetalLB are provided
to make it easier for users to use a LoadBalancer Service.
Edit the [configmap.yaml](./metallb/configmap.yaml) and set
a range of IP addresses MetalLB can use under `data.config.address-pools.addresses`.
This must be in the same subnet as your cluster nodes.

If you do not wish to use a LoadBalancer, change the `spec.type` in [gateway-service.yaml](./kubeflow/common/istio/gateway-service.yaml)
to `NodePort`.

To provide HTTPS out-of-the-box, the `kubeflow-self-signing-issuer` used by internal
Kubeflow applications is setup to provide a certificate for the Istio Ingress
Gateway.

To use a different certificate for the Ingress Gateway, change
the `spec.issuerRef.name` to the cert-manager ClusterIssuer you would like to use in [ingress-certificate.yaml](./kubeflow/common/istio/ingress-certificate.yaml)
and set the `spec.commonName` and `spec.dnsNames[0]` to your Kubeflow domain.

If you would like to use LetsEncrypt, a ClusterIssuer template if provided in
[letsencrypt-cluster-issuer.yaml](./cert-manager/letsencrypt-cluster-issuer.yaml).
Edit this file according to your requirements and uncomment the line in
the [kustomization.yaml](./cert-manager/kustomization.yaml) file
so it is included in the deployment.

### Customizing the Jupyter Web App

To customize the list of images presented in the Jupyter Web App
and other related setting such as allowing custom images,
edit the [spawner_ui_config.yaml](./kubeflow/notebooks/jupyter-web-app/spawner_ui_config.yaml)
file.

### Change ArgoCD application specs and commit

To simplify the process of telling ArgoCD to use your fork
of this repo, a script is provided that updates the
`spec.source.repoURL` of all the ArgoCD application specs.
Simply run:

```bash
./setup_repo.sh <your_repo_fork_url>
```

If you need to target a specific branch or release on your for you can add a second
argument to the script to specify it.

```bash
./setup_repo.sh <your_repo_fork_url> <your_branch_or_release>
```

To change what Kubeflow or third-party componenets are included in the deployment,
edit the [root kustomization.yaml](./kustomization.yaml) and
comment or uncomment the components you do or don't want.

Next, commit your changes and push them to your repository.

### Deploying Kubeflow

Once you've commited and pushed your changes to your repository,
you can either choose to deploy componenet individually or
deploy them all at once.
For example, to deploy a single component you can run:

`kubectl apply -f argocd-applications/kubeflow-roles-namespaces.yaml`

To deploy everything specified in the root [kustomization.yaml](./kustomization.yaml),
 execute:

 `kubectl apply -f kubeflow.yaml`

After this, you should start seeing applications being deployed in
the ArgoCD UI and what the resources each application create.

### Updating the deployment

By default, all the ArgoCD application specs included here are
setup to automatically sync with the specified repoURL.
If you would like to change something about your deployment,
simply make the change, commit it and push it to your fork
of this repo. ArgoCD will automatically detect the changes
and update the necessary resources in your cluster.

### Bonus: Extending the Volumes Web App with a File Browser

A large problem for many people is how to easily upload or download data to and from the
PVCs mounted as their workspace volumes for Notebook Servers. To make this easier
a simple PVCViewer Controller was created (a slightly modified version of
the tensorboard-controller). This feature was not ready in time for 1.3,
and thus I am only documenting it here as an experimental feature as I believe
many people would like to have this functionality. The images are grabbed from my
personal dockerhub profile, but I can provide instructions for people that would
like to build the images themselves. Also, it is important to note that
the PVC Viewer will work with ReadWriteOnce PVCs, even when they are mounted
to an active Notebook Server.

Here is an example of the PVC Viewer in action:

![PVCViewer in action](./images/vwa-pvcviewer-demo.gif)

To use the PVCViewer Controller, it must be deployed along with an updated version
of the Volumes Web App. To do so, deploy
[experimental-pvcviewer-controller.yaml](./argocd-applications/experimental-pvcviewer-controller.yaml) and
[experimental-volumes-web-app.yaml](./argocd-application/experimental-volumes-web-app.yaml)
instead of the regular Volumes Web App. If you are deploying Kubeflow with
the [kubeflow.yaml](./kubeflow.yaml) file, you can edit the root
[kustomization.yaml](./kustomization.yaml) and comment out the regular
Volumes Web App and uncomment the PVCViewer Controller and Experimental
Volumes Web App.
