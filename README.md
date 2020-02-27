# This repo is used for kubernetes learning

## Origin

Original article can be found in [Learn Kubernetes in Under 3 Hours: A Detailed Guide to Orchestrating Containers](https://medium.freecodecamp.org/learn-kubernetes-in-under-3-hours-a-detailed-guide-to-orchestrating-containers-114ff420e882)

Original Repository can be found [here](https://github.com/rinormaloku/k8s-mastery)

## What's new

- Add kubernetes config at each repo (instead of gathering them)
- Try to deploy on AWS EKS
- Try advance features like logging or monitoring
- Know how to develop at local

## Application Demo

The application takes one sentence as input, using Text Analysis, calculates the emotion of the sentence.

![Demo](./docs/demo.gif)

From the technical perspective, the application consists of three microservices. Each has one specific functionality:

* SA-Frontend: a Nginx web server that serves our ReactJS static files.
* SA-WebApp: a Java Web Application that handles requests from the frontend.
* SA-Logic: a python application that performs Sentiment Analysis.

![Demo](./docs/flow.gif)

This interaction is best illustrated by showing how the data flows between them:

1. A client application requests the index.html (which in turn requests bundled scripts of ReactJS application)
2. The user interacting with the application triggers requests to the Spring WebApp.
3. Spring WebApp forwards the requests for sentiment analysis to the Python app.
4. Python Application calculates the sentiment and returns the result as a response.
5. The Spring WebApp returns the response to the React app. (Which then represents the information to the user.)

## Check each service

### Front-end

```
npm install
npm start
```

You should access it on localhost:3000 to take a look. Now make front-end production ready by:

```
npm run build
```

This generates a folder named build in your project tree, which contains all the static files needed for our ReactJS application.

Next, let's dockerize front-end.

```
docker build -f Dockerfile -t sa-frontend .
docker run -d -p 80:80 sa-frontend
```

You should be able to access the react application at `locahost:80`

### Logic

```
docker build -f Dockerfile -t sa-logic .
docker run -d -p 5050:5000 sa-logic
```

### Webapp

```
bash build.bash
docker build -f Dockerfile -t sa-webapp .
docker run -d -p 8080:8080  -e SA_LOGIC_API_URL='http://<container_ip or docker machine ip>:5000' sa-webapp
```

<container_ip or docker machine ip> can be found by using

```docker inspect <sa-logic-container-id>```

Now you get your microservices running:

![Ports](./docs/ports.png)

Try some sentences *I like it* to check if it works

![TestContainer](./docs/test-container.png)

If there are any issues, use `docker container logs` to check service.


## Bring kubernetes to your application

Check out this [post]() to have an overview of kubernetes architecture

Our application in kubernetes could be organized like this:

![RequestToMaster](./docs/request-to-master.png)

![ApplicationLayout](./docs/application-layout.png)


Deployment steps we will proceed include:

* Install tools
* Set up registry
* Create and start a kubernetes cluster
* Verify cluster
* Deploy kubernetes dashboard
* Access dashboard
* Deploy service to cluster
* Setup logging
* View logs
* ....

### Install tools

Since we will use EKS to deploy Kubernetes so you should have one with administration access. You also need fork the repo so you can have Github access token to setup CI/CD later. This part only focuses on deploy locally so having an ubuntu OS is enough !

* Install [docker](https://docs.docker.com/install/linux/docker-ce/ubuntu/) and [docker-compose](https://docs.docker.com/compose/install/)(optional)
* Install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* Install [microk8s](https://microk8s.io/#get-started) (a minikube alternative)

Verify your cluster

```
engineer@engineer-PC:~$ microk8s.kubectl get nodes
NAME          STATUS   ROLES    AGE   VERSION
engineer-pc   Ready    <none>   41h   v1.17.2
engineer@engineer-PC:~$ microk8s.kubectl get pods
No resources found in default namespace.
engineer@engineer-PC:~$ microk8s.kubectl get services
NAME         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   xx.xx.xx.xx    <none>        443/TCP   41h
```

### Setup registry


**Question**: How Kubernetes know where to pull image ?

Images are stored in **registry** and that is location where Kubernetes will look up for images. We can have **local** registry or **remote regitry**. For now we will use local registry to avoid the time spent in uploading/downloading Docker images to/from remote registry.

However, local registry where image created by docker is only know to Docker itself. Kubernetes is not aware of the newly built images properly (We have to configure Kubernetes)

Fortunately, MicroK8s comes with **built-in registry**. This local registry is hosted within the Kubernetes cluster and is exposed as a NodePort service on port 32000 of the localhost. Note that this is an insecure registry and you may need to take extra steps to limit access to it.

* First step is enale this registry
```
$ microk8s.enable registry
Enabling the private registry
Enabling default storage class
[sudo] password for user: 
deployment.apps/hostpath-provisioner unchanged
storageclass.storage.k8s.io/microk8s-hostpath unchanged
serviceaccount/microk8s-hostpath unchanged
clusterrole.rbac.authorization.k8s.io/microk8s-hostpath unchanged
clusterrolebinding.rbac.authorization.k8s.io/microk8s-hostpath unchanged
Storage will be available soon
Applying registry manifest
namespace/container-registry unchanged
persistentvolumeclaim/registry-claim unchanged
deployment.apps/registry unchanged
service/registry unchanged
The registry is enabled
```

The add-on registry is backed up by a 20Gi persistent volume is claimed for storing images. To satisfy this claim the storage add-on is also enabled along with the registry.

The containerd daemon used by MicroK8s is configured to trust this insecure registry. To upload images we have to tag them with localhost:32000/your-image before pushing them.

We can either add proper tagging during build:

```docker build . -t localhost:32000/mynginx:registry```

Or tag an already existing image using the image ID.

```docker tag <image-ID> localhost:32000/mynginx:registry```

Now that the image is tagged correctly, it can be pushed to the registry:

```docker push localhost:32000/mynginx```

Pushing to this insecure registry may fail in some versions of Docker unless the daemon is explicitly configured to trust this registry. See [Configure docker service to use insecure registry
](https://github.com/Juniper/contrail-docker/wiki/Configure-docker-service-to-use-insecure-registry) for more detail.
To address this on Ubuntu we need to edit ```/etc/default/docker``` and update:

```DOCKER_OPTS="--insecure-registry localhost:32000"```

The new configuration should be loaded with a Docker daemon restart:

```sudo systemctl restart docker```

Now, we're ready to push our image to built-in registry

```
cd sa-frontend
docker build -f Dockerfile -t localhost:32000/sa-frontend:registry .
docker push localhost:32000/sa-frontend
cd sa-webapp
docker build -f Dockerfile -t localhost:32000/sa-webapp:registry .
docker push localhost:32000/sa-webapp
cd sa-logic
docker build -f Dockerfile -t localhost:32000/sa-logic:registry .
docker push localhost:32000/sa-logic
```

Output should be like this:

* Frontend

```
$ docker build -f Dockerfile -t localhost:32000/sa-frontend:registry .

Sending build context to Docker daemon  2.042MB
Step 1/2 : FROM nginx
latest: Pulling from library/nginx
68ced04f60ab: Pull complete 
c4039fd85dcc: Pull complete 
c16ce02d3d61: Pull complete 
Digest: sha256:380eb808e2a3b0dd954f92c1cae2f845e6558a15037efefcabc5b4e03d666d03
Status: Downloaded newer image for nginx:latest
 ---> a1523e859360
Step 2/2 : COPY build /usr/share/nginx/html
 ---> 341bf2ddc037
Successfully built 341bf2ddc037
Successfully tagged localhost:32000/sa-frontend:registry

$ docker push localhost:32000/sa-frontend
The push refers to repository [localhost:32000/sa-frontend]
468cb719ccf5: Pushed 
318be7aea8fc: Pushed 
fe08d5d042ab: Pushed 
f2cb0ecef392: Pushed 
registry: digest: sha256:15bc648b344162cf07f1d4ff8767dc2e5e81ab083e8d1d5fe4520119133b61ca size: 1158
```

* SA Logic

```
$ docker build -f Dockerfile -t localhost:32000/sa-logic:registry .

Sending build context to Docker daemon  9.216kB
Step 1/7 : FROM python:3.6.6-alpine
...
Successfully built 1b666de07738
Successfully tagged localhost:32000/sa-logic:registry

$ docker push localhost:32000/sa-logic
The push refers to repository [localhost:32000/sa-logic]
...
```

* SA Webapp

```
$ docker build -f Dockerfile -t localhost:32000/sa-webapp:registry .

Sending build context to Docker daemon  20.52MB
Step 1/5 : FROM openjdk:8-jdk-alpine
 ...
Successfully built db8d2d0b6f43
Successfully tagged localhost:32000/sa-webapp:registry

$ docker push localhost:32000/sa-webapp
The push refers to repository [localhost:32000/sa-webapp]
...
```

### Deploy a Pod

Usually, we wrap one container inside a pod, there will be other cases that we have more container in one pod. For example, we have another container handling heavy jobs in background. So web server container and this worker container should be placed inside a pod so that they can share volumes, or they communicate with each other using inter-process communicatio, ... We also note that one Kubernetes node can contains multi pods. Each pod has a unique IP address in the Kubernetes cluster

Now let's take a look at frontend pod:

```yaml
$ cat sa-frontend/kubernetes/sa-frontend-pod.yaml 
apiVersion: v1
kind: Pod                                          # 1
metadata:
  name: sa-frontend
labels:
  app: sa-frontend                                 # 2
spec:                                              # 3
  containers:
    - image: localhost:32000/sa-frontend:registry  # 4
      name: sa-frontend                            # 5
      ports:
        - containerPort: 80                        # 6
```

* **Kind**: specifies the kind of the Kubernetes Resource that we want to create. In our case, a Pod.
* **Name**: defines the name for the resource. We named it sa-frontend.
* **Label** apply label to this resource so that service can select it
* **Spec** is the object that defines the desired state for the resource. The most important property of a Pods Spec is the Array of containers.
* **Image** is the container image we want to start in this pod.
* **Name** is the unique name for a container in a pod.
* **Container** Port:is the port at which the container is listening. This is just an indicator for the reader (dropping the port doesn’t restrict access).

Now, try to create frontend pod

```
$ microk8s.kubectl create -f sa-frontend/kubernetes/sa-frontend-pod.yaml
pod "sa-frontend" created

$ microk8s.kubectl get pods
NAME          READY   STATUS             RESTARTS   AGE
sa-frontend   0/1     ContainerCreating   0          13s

# take a break

$ microk8s.kubectl get pods
NAME          READY   STATUS             RESTARTS   AGE
sa-frontend   0/1     Running   0          13s
```

**NOTE**: Accessing the application externally

To access the application externally we create a Kubernetes resource of type Service, that will be our next article, which is the proper implementation, but for quick debugging we have another option, and that is port-forwarding:

```
$ microk8s.kubectl port-forward sa-frontend 88:80
Forwarding from 127.0.0.1:88 -> 80
```

Open your browser in 127.0.0.1:88 and you will get to the react application.
Sudo might be need since we use port lower than 1024

### Deploy a service

Why do we need a service type in kubernetes ?

The Kubernetes Service resource acts as the entry point to a set of pods that provide the same functional service. This resource does the heavy lifting, of discovering services and load balancing between them as shown below (Assume we have 2 pod with the same functionality)

![Service](./docs/service.png)

The method is that We **label** pod then apply **selector** to service then it knows which pods are its target. Refer to [here]() to check out **label**

This is service configuration:

```yaml
apiVersion: v1
kind: Service              # 1
metadata:
  name: sa-frontend-lb
spec:
  type: LoadBalancer       # 2
  ports:
  - port: 80               # 3
    protocol: TCP          # 4
    targetPort: 80         # 5
  selector:                # 6
    app: sa-frontend       # 7
```

* **Kind**: A service.
* **Type**: Specification type, we choose LoadBalancer because we want to balance the load between the pods.
* **Port**: Specifies the port in which the service gets requests.
* **Protocol**: Defines the communication.
* **TargetPort**: The port at which incomming requests are forwarded.
* **Selector**: Object that contains properties for selecting pods.
app: sa-frontend Defines which pods to target, only pods that are labeled with “app: sa-frontend”

To create the service execute the following command:

```
$ microk8s.kubectl create -f sa-frontend/kubernetes/service-sa-frontend-lb.yaml
service/sa-frontend-lb created

$ microk8s.kubectl get svc
NAME             TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
sa-frontend-lb   LoadBalancer   10.152.183.213   <pending>     80:32171/TCP   10s
```
The External-IP is in pending state (and don’t wait, as it’s not going to change). This is only because we are using Minikube. If we would have executed this in a cloud provider like Azure or GCP, we would get a Public IP, which makes our services worldwide accessible.

### Deployments

