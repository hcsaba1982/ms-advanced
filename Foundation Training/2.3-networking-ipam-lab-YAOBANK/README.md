## 2.3. Networking: Calico-IPAM Lab

This is the 3rd lab in a series of labs exploring k8s networking. It explores k8s ip adress management via Calico IPAM. deployment in subsequent labs.

In this lab, you will:
2.3.1. Check existing IP Pools  and create new IP Pools 
2.3.2. Update the yaobank deployments with the new IP Pools
2.3.3. Verify host routing

Make sure you are in the right directory:

`cd TRAININGWORKBOOKS/2.3-networking-ipam-lab-YAOBANK`

Change `TRAININGWORKBOOKS` to the directory where you have clone the training labs repository.

### 2.3.1. Check existing IP Pools  and create new IP Pools

Verify that the existing ippool.

```
kubectl get ippool -o yaml
```

```
apiVersion: v1
items:
- apiVersion: crd.projectcalico.org/v1
  kind: IPPool
    name: default-ipv4-ippool
  spec:
    blockSize: 26
    cidr: 10.48.0.0/16
    ipipMode: Never
    natOutgoing: true
    nodeSelector: all()
    vxlanMode: Never
```
We have extracted the relevant information here. You can see from the output that the default pool range is 10.48.0.0/16, which is actually the Calico - Initial default IP Pool range of our k8s cluster.
Note the relevant information in the manifest:

* blockSize: used by Calico IPAM to efficiently assign ad BGP advertize ip addresses in blocks. 
* ipipMode/vxlanMode: to allow or disable ipip and vxlan overlay. options are never, always and crosssubnet

To create new ippools that fall under the k8s cluster CIDR and do not overlap, we create new subnet's into smaller ippools.


Examine the content of the manifest `cat ./lab_manifests/2.3-ippools.yaml`

```
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: pool1-ipv4-ippool
spec:
  blockSize: 26
  cidr: 10.49.0.0/17
  ipipMode: Never
  natOutgoing: true
  nodeSelector: all()

---

apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: pool2-ipv4-ippool
spec:
  blockSize: 26
  cidr: 10.49.128.0/17
  ipipMode: Never
  natOutgoing: true
  nodeSelector: all()
```

You can see that we have effectively broken the default ippool into to equal subnets. 
Apply the manifest and verify the output.

```
calicoctl apply -f ./lab_manifests/2.3-ippools.yaml 
Successfully applied 2 'IPPool' resource(s)
```

```
calicoctl get ippools
NAME                  CIDR             SELECTOR   
default-ipv4-ippool   10.48.0.0/16     all()      
external-pool         10.47.2.0/24     all()      
pool1-ipv4-ippool     10.49.0.0/17     all()      
pool2-ipv4-ippool     10.49.128.0/17   all()    
```

We have now the `pool1-ipv4-ippool` & `pool1-ipv4-ippool' pools to test the ipam address assignment

### 2.3.2. Update the yaobank deployments with the new IP Pools

Now let's update the yao

 the pools that yaobank manifest we have deployed in Lab1, adding annotation to explicitly define the ip pool for each deployment. Examine the manifest ./lab_manifests/2.3-yaobank-ipam.yaml before deploying, specifically the pod the ip pool  annotations.

```
cat ./lab_manifests/2.3-yaobank-ipam.yaml | egrep "kind|name|ipv4pools"
```

```
kind: Namespace
  name: yaobank
kind: Service
  name: database
  namespace: yaobank
    name: http
kind: ServiceAccount
  name: database
  namespace: yaobank
kind: Deployment
  name: database
  namespace: yaobank
        "cni.projectcalico.org/ipv4pools": "[\"pool2-ipv4-ippool\"]"
      - name: database
        kubernetes.io/hostname: worker2
kind: Service
  name: summary
  namespace: yaobank
    name: http
kind: ServiceAccount
  name: summary
  namespace: yaobank
kind: Deployment
  name: summary
  namespace: yaobank
        "cni.projectcalico.org/ipv4pools": "[\"pool2-ipv4-ippool\"]"
      - name: summary
kind: Service
  name: customer
  namespace: yaobank
    name: http
kind: ServiceAccount
  name: customer
  namespace: yaobank
kind: Deployment
  name: customer
  namespace: yaobank
        "cni.projectcalico.org/ipv4pools": "[\"pool1-ipv4-ippool\"]"
      - name: customer
        kubernetes.io/hostname: worker1
```

The annotation explicitly assigns ip pool1 to customer deployment and pool2 to summary and database deployments. Let's apply the manifest and examine the outcome.

```
kubectl apply -f ./lab_manifests/2.3-yaobank-ipam.yaml 

namespace/yaobank unchanged
service/database unchanged
serviceaccount/database unchanged
deployment.apps/database configured
service/summary unchanged
serviceaccount/summary unchanged
deployment.apps/summary configured
service/customer unchanged
serviceaccount/customer unchanged
deployment.apps/customer configured
```

The deployment pods already have ip addresses assigned so we will need to delete the old pods, which will trigger kubernetes scheduler to new pod in conformance with the deployment manifest (the intent) and accordingly apply the ip pool binding.

```
kubectl delete -n yaobank pod $(kubectl get pod -l app=customer -n yaobank -o jsonpath='{.items[0].metadata.name}')
kubectl delete -n yaobank pod $(kubectl get pod -l app=database -n yaobank -o jsonpath='{.items[0].metadata.name}')
kubectl delete -n yaobank pod $(kubectl get pod -l app=summary -n yaobank -o jsonpath='{.items[0].metadata.name}')
kubectl delete -n yaobank pod $(kubectl get pod -l app=summary -n yaobank -o jsonpath='{.items[1].metadata.name}')
```



Next, examine the Pods ip address assignment.

```
kubectl get pod -n yaobank -o wide

NAME                        READY   STATUS    RESTARTS   AGE     IP              NODE      NOMINATED NODE   READINESS GATES
customer-746bdb9f6b-hb85k   1/1     Running   0          9m39s   10.49.2.65      worker1   <none>           <none>
database-64c799fdd7-98gwt   1/1     Running   0          8m57s   10.49.130.66    worker2   <none>           <none>
summary-c75c4c64c-l64fk     1/1     Running   0          8m50s   10.49.130.67    worker2   <none>           <none>
summary-c75c4c64c-z94fx     1/1     Running   0          9m37s   10.49.130.128   worker1   <none>           <none>

```
You can see that Pod ip address assignment is aligned with the intend defined in the updated manifest, assigning pods of a deployment to the correct ip pool.  Calico IPAM provides the flexibility as well of assigning ippools to namespaces or even in alignment with your topology to specific nodes or racks.

### 2.3.3. Verify host routing

Let's check host routing to understand the effect of the subnetting and ip address assignment we have done to routing.

From the above output of `kubectl get pod -n yaobank -o wide` in section 2.3.2, you can see that one customer Pod is running on worker1 and the remaining pods are running on worker2 node. 

Let's first examine the routing table of the worker1 node.

```
ip route
<----snip----->
blackhole 10.49.57.64/26 proto bird 
10.49.57.65 dev calicd5686cd561 scope link 
blackhole 10.49.185.64/26 proto bird 
10.49.185.66 dev cali6ef5877c407 scope link 
10.49.232.64/26 via 10.0.0.12 dev eth0 proto bird 
```

Examine the output of the routing table that is relevant to our deployment:
* specific routes point to the veth interfaces connecting to local pods
* blackhole route is created for the ip block local to the host (saying do route traffic for the local/26 block to any other node)
* routes to the pod on worker2 are learned via BGP and a /26 block advertisement from the nodes

In the end make sure you exit from the worker node and come back to master node.

```
exit
```


> __Congratulations! You have completed you Calico IPAM lab.__ 
