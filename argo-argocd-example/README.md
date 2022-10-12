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

5. Scan the image:  
   XRay or Twistlock

6. Trigger a deployment  
   Update the image tag of the deployment.yaml file that is monitored by Argo CD

7. Run system tests:  
   Cypress or Robot

8. Run security tests:  
   Zap

9. Run performance tests:   

# Setup

1.  Create a builder image  
This is a custom container image that will be used to compile Java Maven projects  
Developers should supply a builder image required to build their source code
```
podman build -t kbachman/kubernetes:maven -f maven.Dockerfile .
```

2.  Start a Maven container  
Run the Maven package commannd to compile code and package a jar file (stored on mounted filesystem)
``` 
podman run -it --rm -v $PWD/target:/usr/src/app/target localhost/kbachman/kubernetes:jarbuilder package -T 1C -o -Dmaven.test.skip=true
```

3. Create a container image for running the Java application
```
podman build -t kbachman/kubernetes:alpine -f jre.Dockerfile .
```

4. Run the application
```
podman run -d --name alpine -p 9000:8080 localhost/kbachman/kubernetes:alpine  
```

5. Test the application
```
curl localhost:9000/actuator/health
```