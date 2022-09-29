# Tekton with ArgoCD

Blueprint for a Tekton + ArgoCD application setup.
Supplementary documentation is here: https://oteemo.atlassian.net/wiki/spaces/OL/pages/2297921537/Tooling+POCs

# Description

The purpose of this repo is to create a mock pipeline that allows for experimenting with Tekton features and determining the difficulty level of working with pipelines in Tekton's yaml syntax.  The main yaml which defines all of the pipeline tasks is located in the [pipeline-buildpacks.yaml](https://github.com/Oteemo/oteemolabs-tools/blob/main/tekton-argocd-example/buildpacks/pipeline-buildpacks.yaml).  Tekton is just performing the CI (build) portion of the pipeline.  ArgoCD will be used for deployments.  Many of the other files in this repo are helper or sample files.  The Tekton tasks that were tested are listed below.  All of the tasks are based on reusable Tasks and Pipelines found at https://hub.tekton.dev/.

1. **Fetch** Java source code from Git (https://github.com/kwbach/springboot_health)
2. **Build** a container image using Paketo cloud native buildpacks
3. **Trigger Deploy** using a sed command to update the image tag in the deployment.yaml file.  ArgoCD will detect the change and redeploy the new image into Kubernetes.


Blueprint for a Tekton + ArgoCD application setup.
Supplementary documentation is here: https://oteemo.atlassian.net/wiki/spaces/OL/pages/2297921537/Tooling+POCs


## Installation

Requires a Kubernetes cluster.  It can be anywhere: local, bare-metal, cloud, it doesn't matter. 

Install Tekton

    kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

Create Secrets

These are needed for SSH GitHub and Docker registry access.  This is one way to create a SSH key, that will be added to GitHub.
There are in fact many ways for Tekton to get access to GitHub.

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

kubectl apply -f tekton-git-ssh-secret.yaml

# create your Docker registry secret, for example:
# find a docker config file with active login to registry
cat ~/.docker/config.json | base64 -w 0
kubectl create secret docker-registry regsecret
--docker-server=https://index.docker.io/v1/ --docker-username=kbachman --docker-password=xxxxxx --docker-email=kbachman@gmail.com
# paste the base64 value into the .dockercfg line of yaml
# save the yaml in home directory, it will need to be tweaked and reapplied later

```

Add Additional Configurations as Needed

```
# GitHub PAT for git cli access on local machine
1. github.com > Settings > Developer Settings > Personal access tokens > Generate new token > copy value
# Run the following wizard to cache the token.  Install gh if it can't be found.
2. gh auth login > GitHub.com > authenticate > HTTPS > enter token

# Add a local host table entry for Kubernetes cluster
sudo nano /private/etc/hosts

# Add connectivity info for another Kubernetes cluster
1. Copy the ~/.kube/config file from the Kubernetes control-plane
2. Add it to ~/.kube/ on the local system with a new file name
3. Add the new config file to the KUBECONFIG env var.  Put it in ~/.zshrc so that it's auto set upon shell login.
export KUBECONFIG=/Users/kevin/.kube/aws:/Users/kevin/.kube/home
# reload the shell config file
source ~/.zshrc
# check and switch to the new context
kubectl config get-contexts
kubectl config use-context <new_config_filename>

# Point kubectl at a different cluster
k config get-contexts
k config use-context kubernetes

```

Setup the Tekton serviceaccount:

    kubectl apply -f tekton/


Install the Tekton Dashboard:

    kubectl apply -f https://github.com/tektoncd/dashboard/releases/latest/download/tekton-dashboard-release.yaml


Install ArgoCD

```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for the pods to enter Running status
# Remove some network policies to avoid timeout errors on the UI and CLI
kubectl delete networkpolicy argocd-repo-server-network-policy
kubectl delete networkpolicy argocd-server-network-policy 
kubectl delete networkpolicy argocd-redis-network-policy  

# Apply customer argocd files
kubectl apply -f argocd/
kubectl apply -n systemtest -f regsecret.yaml
kubectl apply -n production -f regsecret.yaml
```

Login in ArgoCD, find out the admin password and create a token

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

Create ArgoCD Access with Tekton

Under https://localhost:8081/settings/accounts/tekton generate a token.

    kubectl create secret -n tekton-pipelines generic argocd-env-secret '--from-literal=ARGOCD_AUTH_TOKEN=<token>'


Now, adapt all ocurrences of your application and GitOps config repository, and your application Docker image.

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
