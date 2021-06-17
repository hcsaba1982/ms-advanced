## 3.3. Kubernetes Service - Advanced Services Lab

This is the 3rd of a series of labs about k8s services. This lab exposes the Yaobank Customer service to the outside via ingress controller. In this lab, you will: 

3.3.1. Remove previous Yaobank deployment
3.3.2. Deploy an ingress controller that listens to all namespaces
3.3.3. Deploy an updated Yaobank manifest including ingress


### 3.3.0. Before you begin

This lab leverages the lab deployment we have developed so far. If you haven't already done so:
* Deploy Calico as described in Lab1
* Add host1 as a BGP peer as described in Lab2.2

Make sure you are in the right directory:

`cd TRAININGWORKBOOKS/3.3-kubernetes-services-ingress-lab-YAOBANK`

Change `TRAININGWORKBOOKS` to the directory where you have clone the training labs repository.

### 3.3.1. Remove previous Yaobank deployment

In this lab, we will be exposing the Yaobank Customer service using ingress controller. Let's start with removing the previous Yaobank deployment and proceed to deploying the new configuration. For simplicity, let's just remove the namespace which deletes all included objects.

Make sure you are loged in the master node.

```
kubectl delete ns yaobank
```

### 3.3.2. Deploy an ingress controller that listens to all namespaces

Ingress is the built-in kubernetes framework for load-balancing http traffic. Cloud providers offer a similar functionality out of the box via cloud load-balancers. Ingress allows the manipulation of incoming http requests, natting/routing traffic to back-end services based on provided host/path or even passing-through traffic. It can effectively provide l7-based policies and typical load-balancing features such as stickiness, health probes or weight-based load-balancing.


Let's start with examining and the n applying the manifest that sets-up ingress-controller.

```
cat ./lab_manifests/3.3-ingress-controller.yaml
---

apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-ingress-controller
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: ingress-nginx
      app.kubernetes.io/part-of: ingress-nginx
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ingress-nginx
        app.kubernetes.io/part-of: ingress-nginx
      annotations:
        prometheus.io/port: "10254"
        prometheus.io/scrape: "true"
    spec:
      # wait up to five minutes for the drain of connections
      terminationGracePeriodSeconds: 300
      serviceAccountName: nginx-ingress-serviceaccount
      nodeSelector:
        kubernetes.io/os: linux
      containers:
        - name: nginx-ingress-controller
          image: quay.io/kubernetes-ingress-controller/nginx-ingress-controller:master
          args:
            - /nginx-ingress-controller
            - --configmap=$(POD_NAMESPACE)/nginx-configuration
            - --tcp-services-configmap=$(POD_NAMESPACE)/tcp-services
            - --udp-services-configmap=$(POD_NAMESPACE)/udp-services
            - --publish-service=$(POD_NAMESPACE)/ingress-nginx
            - --annotations-prefix=nginx.ingress.kubernetes.io
          securityContext:
            allowPrivilegeEscalation: true
            capabilities:
              drop:
                - ALL
              add:
                - NET_BIND_SERVICE
            # www-data -> 101
            runAsUser: 101
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
            - name: https
              containerPort: 443
              protocol: TCP
          livenessProbe:
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 10
          readinessProbe:
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 10
          lifecycle:
            preStop:
              exec:
                command:
                  - /wait-shutdown

---

---

apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
spec:
  type: NodePort
  ports:
    - name: http
      port: 80
      targetPort: 80
      nodePort: 32080
      protocol: TCP
    - name: https
      port: 443
      targetPort: 443
      nodePort: 32443
      protocol: TCP
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx

---

```

The above configuration sets-up the deployment and service for ingress-controller. By default it listens to all namespaces, once an Ingress object is created in any namespace. This default behaviour can be modified to limit ingress-controller to a specific namespace. Note the nodeport configuration which is exposing port 80 to external port 32080 and port 443 to external port 32443.

Let's proceed with applying the manifest to setup ingress-controller.

```
kubectl apply -f ./lab_manifests/3.3-ingress-controller.yaml
```

Let's examine the output to verify the outcome of the configuration. Note the ports the  service is listening and forwarding to.

```
kubectl get pod -n ingress-nginx -o wide
```

```
ubuntu@master:$ kubectl get pod -n ingress-nginx -o wide
NAME                                        READY   STATUS    RESTARTS   AGE   IP             NODE      NOMINATED NODE   READINESS GATES
nginx-ingress-controller-7fcb6cffc5-xwskb   1/1     Running   0          47s   10.48.189.67   worker2   <none>           <none>
```

```
kubectl get svc -n ingress-nginx 
```

```
ubuntu@master:$ kubectl get svc -n ingress-nginx
NAME            TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx   NodePort   10.49.45.111   <none>        80:32080/TCP,443:32443/TCP   76s

```

### 3.3.3. Deploy an updated Yaobank manifest including ingress

Next, let's examine the updated Yaobank configuration manifest and then apply it.  We have extracted the modification in this manifest versus the original Yaobank manifest.

```
$ cat ./lab_manifests/3.3-yaobank.yaml

---
apiVersion: v1
kind: Service
metadata:
  name: customer
  namespace: yaobank
  labels:
    app: customer
spec:
  ports:
  - port: 80
    name: http
  selector:
    app: customer

---

apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: ingress-yaobank-customer 
  namespace: yaobank
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
    - host: user.yaobank.lab.tigera.ca
      http:
        paths:
          - pathType: Prefix
            path: /
            backend:
              serviceName: customer
              servicePort: 80
```

Notice the change to the service where nodeport configuration has been removed.

Ingress configuration has been added, tapping into the cluster ingress-controller.

Let's apply the configuration and examine the outcom

```
kubectl apply -f ./lab_manifests/3.3-yaobank.yaml
```

```
kubectl get svc -n yaobank
```

```
ubuntu@master:~$ kubectl get svc -n yaobank
NAME       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
customer   ClusterIP   10.49.196.110   <none>        80/TCP     93s
database   ClusterIP   10.49.133.61    <none>        2379/TCP   94s
summary    ClusterIP   10.49.121.157   <none>        80/TCP     93s
ubuntu@master:~$ 
ubuntu@master:~$ kubectl get svc -n ingress-nginxNAME            TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx   NodePort   10.49.168.23   <none>        80:32080/TCP,443:32443/TCP   53s
ubuntu@master:~$ 
```

Verify access to the service from within the cluster.

```
curl 10.49.196.110
```

```
ubuntu@master:~$ curl 10.49.196.110
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>YAO Bank</title>
    <style>
    h2 {
      font-family: Arial, Helvetica, sans-serif;
    }
    h1 {
      font-family: Arial, Helvetica, sans-serif;
    }
    p {
      font-family: Arial, Helvetica, sans-serif;
    }
    </style>
  </head>
  <body>
        <h1>Welcome to YAO Bank</h1>
        <h2>Name: Spike Curtis</h2>
        <h2>Balance: 2389.45</h2>
        <p><a href="/logout">Log Out >></a></p>
  </body>
</html>ubuntu@master:~$ 
```

Now verify access from outside of the cluster:

Login to bird node

```
bird
```

Run the following command to enable DNS Lookup of the service URL.

`sudo bash -c "echo '10.49.168.23 user.yaobank.lab.tigera.ca' >> /etc/hosts"`

*Change the `10.49.168.23` IP to your serivce IP.*

Finally try to access the url.

```
curl http://user.yaobank.lab.tigera.ca
```

Exit out of bird node

```
exit
```

> Congratulations! You have successfully completed your k8s services training module.