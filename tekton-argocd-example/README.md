# Tekton with Argo CD

Protoype for a Tekton + Argo CD pipeline.
Supplementary documentation is here: https://oteemo.atlassian.net/wiki/spaces/OL/pages/2297921537/Tooling+POCs

## Description

The purpose of this repo is to create a CI/CD pipeline prototype that allows for experimenting with Tekton and Argo CD features.

Tekton performs the CI (build) portion of the pipeline.  Argo CD handles the deployments.  Reusable tasks with hub- prepended to the filenames were downloaded from the Tekton hub at https://hub.tekton.dev/.
## Installation

Requires a Kubernetes cluster.  It can be anywhere: local, bare-metal, cloud, it doesn't matter. 

### Tekton

#### Install
```
    # Clone this repository
    git clone https://github.com/Oteemo/oteemolabs-tools.git
    cd tekton-argocd-example

    # Create custom resource definitions (CRDs)
    kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

    # Create service account
    kubectl apply -f tekton/

    # Install the Dashboard:
    kubectl apply -f https://github.com/tektoncd/dashboard/releases/latest/download/tekton-dashboard-release.yaml
```


    
#### Add Credentials

These are needed for SSH Git and image registry access.  This is one way to create a SSH key, that will be added to GitHub. There are in fact many ways for Tekton to get access to GitHub.

*Consider replacing this with a SOPS secret in the future*  
*Consider making these instructions less verbose*

```
ssh-keygen -t rsa -b 4096 -C "tekton@tekton.dev"
# save as tekton / tekton.pub
# add tekton.pub contents to GitHub

# create secret YAML from contents
cat tekton | base64 -w 0
cat > tekton-git-ssh-secret.yaml << EOM
apiVersion: v1
kind: Secret
metadata:
  name: git-ssh-key
  namespace: tekton-pipelines
  annotations:
    tekton.dev/git-0: github.com
type: kubernetes.io/ssh-auth
data:
  ssh-privatekey: <base64 data>
---
EOM

# create the secret in Kubernetes
kubectl apply -f tekton-git-ssh-secret.yaml

# create your image registry secret, for example:
# find a docker config file with active login to registry
cat ~/.docker/config.json | base64 -w 0


kubectl create secret docker-registry regsecret
--docker-server=https://index.docker.io/v1/ --docker-username=kbachman --docker-password=xxxxxx --docker-email=kbachman@gmail.com

# paste the base64 value into the .dockercfg line of yaml
# save the yaml in home directory, it will need to be tweaked and reapplied later

```

### Argo CD

#### Install

```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for the pods to enter Running status
# Remove some network policies to avoid timeout errors on the UI and CLI
kubectl delete networkpolicy argocd-repo-server-network-policy
kubectl delete networkpolicy argocd-server-network-policy 
kubectl delete networkpolicy argocd-redis-network-policy  

```

#### Login

```
# Username = admin
# Password (get with the command below, drop the trailing %)
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# The password can be customized with this command, go to https://www.browserling.com/tools/bcrypt to generate a new hash
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {
    "admin.password": "<put bcrypt hash here>",
    "admin.passwordMtime": "'$(date +%FT%T%Z)'"
  }}'

# forward ports to access in browser
kubectl -n argocd port-forward svc/argocd-server 8081:80
kubectl -n tekton-pipelines port-forward svc/tekton-dashboard 9097:9097
# expose argocd externally by creating the let's encrypt ingress yaml shown here:
https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#kubernetesingress-nginx
# the same can be done for tekton endpoints, search the web for tekton ingress examples
```

### Integration
Create Argo CD Access with Tekton

Under https://localhost:8081/settings/accounts/tekton generate a token.

    kubectl create secret -n tekton-pipelines generic argocd-env-secret '--from-literal=ARGOCD_AUTH_TOKEN=<token>'


Now, adapt all ocurrences of your application and GitOps config repository, and your application container image.

Then you can execute the pipeline, manually:

 
    ./pipelinerun/trigger-pipeline.sh


##  Testing Tasks and Pipelines

### Hello World Task
```
k apply -f https://raw.githubusercontent.com/kwbach/tekton-argocd-example/main/hello/task-hello.yaml
k apply -f https://raw.githubusercontent.com/kwbach/tekton-argocd-example/main/hello/task-run-hello.yaml
```
The task can be executed a few ways:

1.  kubectl create # use create instead of apply because of the auto-generated name
2.  From the UI at TaskRuns > Name > Rerun
3.  From the CLI: tkn task start echo-hello-world

### Print README Pipeline
```
# Add support for the git clone task on Tekton Hub
kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.6/git-clone.yaml

# Apply the Pipeline and PipelineRun.  Applying the PipelineRun yaml will start the pipeline.
k apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.6/samples/git-clone-checking-out-a-branch.yaml
```
The pipeline can be executed a few ways:

1.  kubectl create # use create instead of apply because of the auto-generated name
2.  From the UI at PipelineRuns > Name > Rerun
3.  From the CLI: tkn pipeline start cat-branch-readme


## Tekton Triggers

You can setup Tekton Triggers that start the build on a push to the repository `main` branch.

Install Tekton Triggers:

```
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
kubectl apply -f pipelinetriggers/
```

Create a triggers secret for GitHub:

```
cat > github-trigger-secret.yaml << EOM
apiVersion: v1
kind: Secret
metadata:
  name: github-trigger-secret
  namespace: tekton-pipelines
type: Opaque
stringData:
  secretToken: "123"
---
EOM

kubectl apply -f github-trigger-secret.yaml
```

Test the triggers setup manually:

```
# HMAC is generated from payload and the GitHub triggers secret
curl -i \
  -H 'X-GitHub-Event: push' \
  -H 'X-Hub-Signature: sha1=<HMAC>' \
  -H 'Content-Type: application/json' \
  -d '{"ref":"refs/heads/main","head_commit":{"id":"123abc..."}}' \
  http://tekton-triggers.example.com
```

After you've setup a GitHub WebHook for push events, you can test the pipeline via pushing to you application repository.
