## 4.1. Policy: Basic Calico Network Policy Lab

This is the first lab of a series of labs focusing on Calico k8s network policy. Throughout this lab we will deploy and test our first Calico k8s network policy. 
In this lab we will:

4.1.1. Verify connectivity from customer pod
4.1.2. Apply a simple Calico Policy

### 4.1.0. Before you begin

Throughout this lab, we will be using the yaobank app we deployed in Lab1.
If you haven't done so, please go back and complete Lab1.

Make sure you are in the right directory:

`cd TRAININGWORKBOOKS/4.1-policy-calico-basic-lab-YAOBANK`

Change `TRAININGWORKBOOKS` to the directory where you have clone the training labs repository.

```
kubectl delete -f ../3.3-kubernetes-services-ingress-lab-YAOBANK/lab_manifests/3.3-ingress-controller.yaml
kubectl delete -f ../3.3-kubernetes-services-ingress-lab-YAOBANK/lab_manifests/3.3-yaobank.yaml 
kubectl apply -f ../1-install-calico-k8s-lab/lab_manifests/1-yaobank.yaml
```

### 4.1.1. Verify connectivity from the yaobank pod

Make sure you are connected to master node.

Let's start with checking the ip address information of our deployment.

```
kubectl get pod -n yaobank -o wide
```

```
ubuntu@master:~$ kubectl get pod -n yaobank -o wide
NAME                        READY   STATUS    RESTARTS   AGE    IP             NODE      NOMINATED NODE   READINESS GATES
customer-747d66f8bf-jhl2l   1/1     Running   0          113s   10.47.2.236    worker1   <none>           <none>
database-746b78cf85-j28tw   1/1     Running   0          113s   10.48.189.84   worker2   <none>           <none>
summary-85c56b76d7-2kjzb    1/1     Running   0          113s   10.48.189.85   worker2   <none>           <none>
summary-85c56b76d7-ngm6t    1/1     Running   0          113s   10.47.2.235    worker1   <none>           <none>
ubuntu@master:~$ 
```

```
kubectl get svc -n yaobank
```

```
ubuntu@master:~$ kubectl get svc -n yaobank
NAME       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
customer   NodePort    10.49.200.142   <none>        80:30180/TCP   2m7s
database   ClusterIP   10.49.128.187   <none>        2379/TCP       2m7s
summary    ClusterIP   10.49.218.181   <none>        80/TCP         2m7s
ubuntu@master:~$ 
```

Next, Let's exec into the customer pod and verify connectivity to the summary pod in worker1/2.

```
kubectl exec -ti -n yaobank $(kubectl get pod -l app=customer -n yaobank -o name) -- bash
```

```
kubectl exec -ti -n yaobank $(kubectl get pod -l app=customer -n yaobank -o name) -- bash
	ping 10.48.189.85
	ping 10.47.2.235
	curl -v telnet://10.48.189.85:80
	curl -v telnet://10.47.2.235:80
	ping summary
	curl -v telnet://summary:80
	exit
```

You should have the following behaviour:

* ping to the pod ip is successful
* curl to the pod ip is successful
* ping to summary fails
* curl to summary is successful

As we have learned in Lab3, services are serviced by kube-proxy which load-balances the service request to backing pods. The service is listening to TCP port 80 so the ping failure is expected.

We have setup NodePort 30180 for the customer service as part of the manifest. Verify external access from your browser.

*Change 54.245.183.130 IP to your master IP address*

```
http://54.245.183.130:30180/
```

```
Welcome to YAO Bank
Name: Spike Curtis
Balance: 2389.45
Log Out >>
```

The IP will be different in your lab environment.

### 4.1.2. Apply a simple Calico Policy

Let's limit connectivity on the Nginx pods to only allow inbound traffic to port 80 from the CentOS pod.
Examine the manifest before applying it:

``` 
cat ./lab_manifests/4.1-customer2summary.yaml 

apiVersion: projectcalico.org/v3
kind: NetworkPolicy
metadata:
  name: customer2summary
  namespace: yaobank
spec:
  order: 500
  selector: app == "summary"
  ingress:
  - action: Allow
    protocol: TCP
    source:
      selector: app == "customer"
    destination:
      ports:
      - 80
  types:
    - Ingress
```

The policy allows matches the label app=summary which is assigned to summary pods, and allows TCP port 80 traffic from source matching the label app=customer which is assigned to customer pods.
Let's apply our first Calico network policy and examine the effect.

```
calicoctl apply -f ./lab_manifests/4.1-customer2summary.yaml 
Successfully applied 1 'NetworkPolicy' resource(s)
```

Now, let's repeat the tests we have done in section 4.1.1 from the master node.
You should have the following behaviour:

* ping to the pod now fails. This is expected since icmp was not allowed in the policy we have applied.
* curl to the pod ip is successful
* ping to summary fails
* curl to summary is successful

Let's cleanup the network policy for now.

```
calicoctl delete -f ./lab_manifests/4.1-customer2summary.yaml 
Successfully deleted 1 'NetworkPolicy' resource(s)
```
> __Congratulations! You have completed your first Calico network policy lab.__
