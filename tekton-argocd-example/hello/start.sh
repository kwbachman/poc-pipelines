# Instructions for manually starting a task or pipeline in the /hello folder

# Run these commands if the tasks or pipeline haven't been defined yet.  Applying the "Run" resources will automatically start a task and pipeline.
kubectl apply -f /hello -n tekton-pipelines

# Rerun the task and pipeline with kubectl
kubectl create -f task-run-hello.yaml -n tekton-pipelines
kubectl create -f pipeline-run-print-readme.yaml -n tekton-pipelines

# Rerun the task and pipeline with tkn
tkn task start echo-hello-world
tkn pipeline start cat-branch-readme

# Rerun the task and pipeline with UI
TaskRuns > echo-hello-world-task-run- > Rerun
PipelineRuns > show-readme- > Rerun
