# Advanced Pipeline Stages / Steps

Prerequisite:
Create a custom builder image that so that a container can be used to compile your source code into an executable file
See the builder.Dockerfile in this directory for an example


1. Clone source repository to local directory
   ```
   git clone repo
   ```

2. Scan source code

   a. Scan dependencies for vulnerabilities:  
   Sonatype Nexus, OSSIndex, or OWASP Dependency-check

   b. Scan for code covered by unit tests:  
   Sonarqube

3. Compile source code  
   Pass parameters to your builder image as shown in this example
   ```
   podman run -it --rm -v $(shell pwd)/target:/usr/src/app/target myrep/mvn-builder package -T 1C -o -Dmaven.test.skip=true
   ```

4. Build and push a container image:  
   Kaniko Argo Workflows Hub

5. Trigger a deployment  
   Update the image tag of the deployment.yaml file that is monitored by Argo CD


# Simple Pipeline Stages / Steps

