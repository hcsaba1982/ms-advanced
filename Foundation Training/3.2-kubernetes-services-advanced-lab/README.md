## 3.2. Kubernetes Service - Advanced Services Lab

This is the 2nd of a series of labs about k8s services. This lab explores different scenarios for advertising services ip addresses via BGP. In this lab, you will: 

3.2.1. Advertise the service IP range

3.2.2. Advertise individual service cluster IP

3.2.3. Advertise individual service external IP

### 3.2.0. Before you begin

This lab builds on previous lab setup and requires Calico CNI to setup, Yaobank application deployed and BGP peering established with bird. If you haven't already done so:
* Deploy Calico and the YAO Bank sample application as described in Lab1
* Add bird as a BGP peer as described in Lab2.2

Make sure you are in the right directory:

`cd TRAININGWORKBOOKS/3.2-kubernetes-services-advanced-lab`

Change `TRAININGWORKBOOKS` to the directory where you have clone the training labs repository.

### 3.2.1. Advertise service cluster IP addresses

Advertising services over BGP allows you to directly access the service without using NodePorts or a cluster Ingress Controller.

#### 3.2.1.1. Examine routes
Before we begin lets first remember what we buillt in lab 2.2.
On the master node run `kubectl get pod -n external-ns -o wide` & `kubectl get pod -n yaobank -o wide` commands and note down the IP addresses of the pods. Should look something like this.

```
ubuntu@master:~$ kubectl get pod -n external-ns -o wide
NAME                     READY   STATUS    RESTARTS   AGE   IP            NODE      NOMINATED NODE   READINESS GATES
nginx-5bccf56c9f-h6k5r   1/1     Running   0          37h   10.47.2.232   worker1   <none>           <none>

ubuntu@master:~$ kubectl get pod -n yaobank -o wide
NAME                        READY   STATUS    RESTARTS   AGE     IP              NODE      NOMINATED NODE   READINESS GATES
customer-747d66f8bf-wj6nd   1/1     Running   0          5m7s    10.47.2.236     worker1   <none>           <none>
database-746b78cf85-5lm5t   1/1     Running   0          4m31s   10.48.189.124   worker2   <none>           <none>
summary-85c56b76d7-cbhc2    1/1     Running   0          4m27s   10.47.2.237     worker1   <none>           <none>
summary-85c56b76d7-lh6dx    1/1     Running   0          3m54s   10.48.189.119   worker2   <none>           <none>
```

*If you have not done so in lab 2.3, please delete the YAOBANK PODs once, so that they are assigned IPs from the right pool*
You can do so by running the below commands.

```
kubectl delete -n yaobank pod $(kubectl get pod -l app=customer -n yaobank -o jsonpath='{.items[0].metadata.name}')
kubectl delete -n yaobank pod $(kubectl get pod -l app=database -n yaobank -o jsonpath='{.items[0].metadata.name}')
kubectl delete -n yaobank pod $(kubectl get pod -l app=summary -n yaobank -o jsonpath='{.items[0].metadata.name}')
kubectl delete -n yaobank pod $(kubectl get pod -l app=summary -n yaobank -o jsonpath='{.items[1].metadata.name}')
```

Now run `calicoctl get ippools` to see the IP Pools.

```
ubuntu@master:~$ calicoctl get ippools
NAME                  CIDR             SELECTOR   
default-ipv4-ippool   10.48.0.0/16     all()      
external-pool         10.47.2.0/24     all()      
pool1-ipv4-ippool     10.49.2.0/24     all()      
pool2-ipv4-ippool     10.49.130.0/24   all()     
```

As you can see the PODs is assigned IP address from `external-pool`, `pool1-ipv4-ippool` and `pool2-ipv4-ippool` IP Pools accordingly based on our last few labs.
*Note: These pools is then divided into blocks and assigned to each node. Lets take a look how it looks like outside the cluster.*

Lets take a look at the state of routes on the standalone host (bird). Connect to the host by typing `bird` on the master node and hitting enter.

Finally look at the routing table of that node.

```
bird
```

```
ip route
```

```
ubuntu@ip-10-0-0-20:~$ ip route
default via 10.0.0.1 dev eth0 proto dhcp src 10.0.0.20 metric 100 
10.0.0.0/24 dev eth0 proto kernel scope link src 10.0.0.20 
10.0.0.1 dev eth0 proto dhcp scope link src 10.0.0.20 metric 100 
10.47.2.232/29 via 10.0.0.11 dev eth0 proto bird 
10.48.189.64/26 via 10.0.0.12 dev eth0 proto bird 
10.48.219.64/26 via 10.0.0.10 dev eth0 proto bird 
10.48.235.128/26 via 10.0.0.11 dev eth0 proto bird 
10.49.57.64/26 via 10.0.0.11 dev eth0 proto bird 
10.49.185.64/26 via 10.0.0.11 dev eth0 proto bird 
10.49.232.64/26 via 10.0.0.12 dev eth0 proto bird 
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown
```

As you can see above the routes learned via BGP ending with `proto bird` prefix are the blocks in which `yaobank` Applications and `nginx` POD are running.
Calico advertises the IP Ranges by default to the external neighboring devices, `bird` host in our case.
By default each node is advertising assigned block from service cluster IP range i.e. in our case `10.49.x.y/26`
However, what if we want to have more control over it or summarize the IP subnet and advertise it with bigger block.
Lets advertise the Cluster Service IP Subnet via BGP from Calico and see what happens


#### 3.2.1.2. Add Calico BGP configuration

Examine the default BGP configuration we are about to apply
```
more ./lab_manifests/3.2-default-bgp.yaml
```
The `serviceClusterIPs` clause tells Calico to advertise the cluster IP range.

Apply the configuration
```
calicoctl apply -f ./lab_manifests/3.2-default-bgp.yaml
```

Verify the BGPConfiguration contains the `serviceClusterIPs` key
```
calicoctl get bgpconfig default -o yaml
```
```
ubuntu@bird:~/calico/lab-manifests$ calicoctl get bgpconfig default -o yaml
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata:
  creationTimestamp: "2021-03-09T15:02:16Z"
  name: default
  resourceVersion: "1400163"
  uid: 79e902d8-0cda-494a-862b-fd09a4cfb809
spec:
  asNumber: 64512
  logSeverityScreen: Info
  nodeToNodeMeshEnabled: true
  serviceClusterIPs:
  - cidr: 10.49.0.0/16
  serviceExternalIPs:
  - cidr: 10.50.0.0/24
```

#### 3.2.1.3. Examine routes

Now lets re-examine the routes again on bird.

```
ip route
```
```
default via 10.0.0.1 dev eth0 proto dhcp src 10.0.0.20 metric 100 
10.0.0.0/24 dev eth0 proto kernel scope link src 10.0.0.20 
10.0.0.1 dev eth0 proto dhcp scope link src 10.0.0.20 metric 100 
10.47.2.232/29 via 10.0.0.11 dev eth0 proto bird 
10.48.189.64/26 via 10.0.0.12 dev eth0 proto bird 
10.48.219.64/26 via 10.0.0.10 dev eth0 proto bird 
10.48.235.128/26 via 10.0.0.11 dev eth0 proto bird 
10.49.0.0/16 proto bird 
        nexthop via 10.0.0.10 dev eth0 weight 1 
        nexthop via 10.0.0.11 dev eth0 weight 1 
        nexthop via 10.0.0.12 dev eth0 weight 1 
10.49.2.64/26 via 10.0.0.11 dev eth0 proto bird 
10.49.130.64/26 via 10.0.0.12 dev eth0 proto bird 
10.49.130.128/26 via 10.0.0.11 dev eth0 proto bird 
10.50.0.0/24 proto bird 
        nexthop via 10.0.0.10 dev eth0 weight 1 
        nexthop via 10.0.0.11 dev eth0 weight 1 
        nexthop via 10.0.0.12 dev eth0 weight 1 
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown
```
You should now see the cluster service cidr `10.49.0.0/16` advertised from each of the kubernetes cluster nodes. This means that traffic to any service's cluster IP address will get load-balanced across all nodes in the cluster by the network using ECMP (Equal Cost Multi Path). Kube-proxy then load balances the cluster IP across the service endpoints (backing pods) in exactly the same way as if a pod had accessed a service via a cluster IP.

Exist out of bird and return to master node.

```
exit
```

#### 3.2.1.4. Verify we can access cluster IPs

Find the cluster IP for the `customer` service.

```
kubectl get svc -n yaobank customer
```
```
ubuntu@bird:~$ kubectl get svc -n yaobank customer
NAME       TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
customer   NodePort   10.49.204.171   <none>        80:30180/TCP   15h
```
In this example output it is `10.49.204.171`. Your IP may be different.

Log in to bird node to verify connectivity

```
bird
```

Confirm you can access it from bird.

```
curl 10.49.204.171
```

```
ubuntu@ip-10-0-0-20:~$ curl 10.49.204.171
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
</html>
```

Exist out of bird and return to master node.

```
exit
```

### 3.2.2. Advertise local service cluster IP addresses

You can set `externalTrafficPolicy: Local` on a Kubernetes service to request that external traffic to a service should only be routed via nodes which have a local service endpoint (backing pod). This preserves the client source IP and avoids the second hop associated  NodePort or ClusterIP services when kube-proxy loadbalances to a service endpoint (backing pod) on another node.

Traffic to the cluster IP for a service with `externalTrafficPolicy: Local` will be load-balanced across the nodes with endpoints for that service.

#### 3.2.2.1. Add external traffic policy

Update the `customer` service to add `externalTrafficPolicy: Local`.

```
kubectl patch svc -n yaobank customer -p '{"spec":{"externalTrafficPolicy":"Local"}}'
```

#### 3.2.2.2. Examine routes

Find the cluster IP for the `customer` service.

```
kubectl get svc -n yaobank customer
```
```
ubuntu@bird:~$ kubectl get svc -n yaobank customer
NAME       TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
customer   NodePort   10.49.204.171   <none>        80:30180/TCP   15h
```
In this example output it is `10.49.204.171`. Your IP may be different.

Login to bird node.

```
bird
```

```
ip route
```
```
ubuntu@ip-10-0-0-20:~$ ip route
default via 10.0.0.1 dev eth0 proto dhcp src 10.0.0.20 metric 100 
10.0.0.0/24 dev eth0 proto kernel scope link src 10.0.0.20 
10.0.0.1 dev eth0 proto dhcp scope link src 10.0.0.20 metric 100 
10.47.2.232/29 via 10.0.0.11 dev eth0 proto bird 
10.48.189.64/26 via 10.0.0.12 dev eth0 proto bird 
10.48.219.64/26 via 10.0.0.10 dev eth0 proto bird 
10.48.235.128/26 via 10.0.0.11 dev eth0 proto bird 
10.49.0.0/16 proto bird 
        nexthop via 10.0.0.10 dev eth0 weight 1 
        nexthop via 10.0.0.11 dev eth0 weight 1 
        nexthop via 10.0.0.12 dev eth0 weight 1 
10.49.2.64/26 via 10.0.0.11 dev eth0 proto bird 
10.49.130.64/26 via 10.0.0.12 dev eth0 proto bird 
10.49.130.128/26 via 10.0.0.11 dev eth0 proto bird 
10.49.204.171 via 10.0.0.11 dev eth0 proto bird
10.50.0.0/24 proto bird 
        nexthop via 10.0.0.10 dev eth0 weight 1 
        nexthop via 10.0.0.11 dev eth0 weight 1 
        nexthop via 10.0.0.12 dev eth0 weight 1 
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown 
```

You should now have a `/32` route for the yaobank customer service (`10.49.204.171` in the above example output) advertised from the node hosting the customer service pod (worker1, `10.0.0.11` in this example output).

For each active service with `externalTrafficPolicy: Local`, Calico advertise the IP for that service as a `/32` route from the nodes that have endpoints for that service. This means that external traffic to the service will get load-balanced across all nodes in the cluster that have a service endpoint (backing pod) for the service by the network using ECMP (Equal Cost Multi Path). Kube-proxy then DNATs the traffic to the local backing pod on that node (or load-balances equally to the local backing pods if there is more than one on the node).

The two main advantages of using `externalTrafficPolicy: Local` in this way are:
* There is a network efficiency win avoiding potential second hop of kube-proxy load-balancing to another node.
* The client source IP addresses are preserved, which can be useful if you want to restrict access to a service to specific IP addresses using network policy applied to the backing pods.  (This is an alternative approach to that we will explore later in Lab4.2 where will use Calico host endpoint `preDNAT` policy to restict external traffic to the services.)


#### 3.2.2.3. Note the impact on nodePorts
Earlier in these labs we accessed the YAO Bank frontend UI from your browser. The link you were using maps to a nodePort on `master1`. As we've now set `externalTrafficPolicy: Local`, this will no longer work since there are no `customer` pods hosted on `master1`. Accessing via the nodePort on `worker1` would work indeed.

For instance you can open your browser and try `http://54.245.183.130:30180/` replace `54.245.183.130` with your worker1 IP.

### 3.2.3. Advertise service external IP addresses

If you want to advertise a service using an IP address outside of the service cluster IP range, you can configure the service to have one or more `externalIPs`.

#### 3.2.3.1. Examine the existing services
Before we begin, examine the kubernetes services in the `yaobank` kubernetes namespace.

```
kubectl get svc -n yaobank
```
```
ubuntu@bird:~/calico/lab-manifests$ kubectl get svc -n yaobank
NAME       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
customer   NodePort    10.49.204.171   <none>        80:30180/TCP   16h
database   ClusterIP   10.49.131.165   <none>        2379/TCP       16h
summary    ClusterIP   10.49.153.90    <none>        80/TCP         16h
```

Note that none of them currently have an `EXTERNAL-IP`.

#### 3.2.3.2. Update BGP configuration

Update the Calico BGP configuration to advertise a service external IP CIDR range of `10.50.0.0/24`.

```
calicoctl patch BGPConfig default --patch \
   '{"spec": {"serviceExternalIPs": [{"cidr": "10.50.0.0/24"}]}}'
```

Note that `serviceExternalIPs` is a list of CIDRs, so you could for example add individual /32 IP addresses if there were just a small number of specific IPs you wanted to advertise.

#### 3.2.3.2. Examine routes

Login to bird node.

```
bird
```

```
ip route
```
```
ubuntu@ip-10-0-0-20:~$ ip route
default via 10.0.0.1 dev eth0 proto dhcp src 10.0.0.20 metric 100 
10.0.0.0/24 dev eth0 proto kernel scope link src 10.0.0.20 
10.0.0.1 dev eth0 proto dhcp scope link src 10.0.0.20 metric 100 
10.47.2.232/29 via 10.0.0.11 dev eth0 proto bird 
10.48.189.64/26 via 10.0.0.12 dev eth0 proto bird 
10.48.219.64/26 via 10.0.0.10 dev eth0 proto bird 
10.48.235.128/26 via 10.0.0.11 dev eth0 proto bird 
10.49.0.0/16 proto bird 
        nexthop via 10.0.0.10 dev eth0 weight 1 
        nexthop via 10.0.0.11 dev eth0 weight 1 
        nexthop via 10.0.0.12 dev eth0 weight 1 
10.49.2.64/26 via 10.0.0.11 dev eth0 proto bird 
10.49.130.64/26 via 10.0.0.12 dev eth0 proto bird 
10.49.130.128/26 via 10.0.0.11 dev eth0 proto bird 
10.49.204.171 via 10.0.0.11 dev eth0 proto bird 
10.50.0.0/24 proto bird 
        nexthop via 10.0.0.10 dev eth0 weight 1 
        nexthop via 10.0.0.11 dev eth0 weight 1 
        nexthop via 10.0.0.12 dev eth0 weight 1 
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown 
```

You should now have a route for the external ID CIDR (10.50.0.10/24) with next hops to each of our cluster nodes.

Exist out of bird and return to master node.

```
exit
```

#### 3.2.3.4. Assign the service external IP

Assign the service external IP `10.50.0.10` to the `customer` service.
```
kubectl patch svc -n yaobank customer -p  '{"spec": {"externalIPs": ["10.50.0.10"]}}'
```

Examine the services again to validate everything is as expected:
```
kubectl get svc -n yaobank
```
```
ubuntu@bird:~/calico/lab-manifests$ kubectl get svc -n yaobank
NAME          TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
customer      NodePort       10.49.204.171    10.50.0.10    80:30180/TCP   59m
database      ClusterIP      10.49.252.124   <none>        2379/TCP       59m
summary       ClusterIP      10.49.163.205   <none>        80/TCP         59m

```

You should now see the external ip (`10.50.0.10`) assigned to the `customer` service.  We can now access the `customer` service from outside the cluster using the external ip address (10.50.0.10) we just assigned.

#### 3.2.3.5. Verify we can access the service's external IP

Connect to the `customer` service from the bird node using the service external IP `10.50.0.10`.

Login to bird node.

```
bird
```

```
curl 10.50.0.10
```

```
ubuntu@ip-10-0-0-20:~$ curl 10.50.0.10
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
</html>ubuntu@ip-10-0-0-20:~$ 
```

Exist out of bird and return to master node.

```
exit
```

As you can see the service has been made available outside of the cluster via bgp routing and load balancing.

### 3.2.4. Recap

We've covered five different ways so far in our lab for connecting to your pods from outside the cluster.
* Via a standard NodePort on a specific node. (This is how you connected to the YAO Bank web front end from your browser)
* Direct to the pod IP address by configuring a Calico IP Pool that is externally routable.
* Advertising the service cluster IP range. (And using ECMP to load balance across all nodes in the cluster)
* Advertising individual cluster IPs. (Services with `externalTrafficPolicy: Local`, using ECMP to load balance only to the nodes hosting the pods backing the service)
* Advertising service external-IPs. (So you can use service IP addresses outside of the cluster IP range)

There are more ways for cluster external connectivity, nonetheless we have covered the most common scenarios. This gives you an idea about Calico's versatility and ability to fit with a broad range of networking needs.

> __Congratulation! You have completed this lab and you have by now a good understanding of k8s services external connectivity__

