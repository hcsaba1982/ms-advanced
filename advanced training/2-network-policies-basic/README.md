# 2. Network Policies Basics
In this lab we will implement basic policies to secure yaobank app and setup policy hierarchy. 

Steps: 
2.1. Setup policy tiers
2.2. Apply policies to allow dns 
2.3. Apply policies to secure yaobank app
2.4. Test


## 2.1. Setup policy tiers

The first step is to setup policy tiers which represent the policy hierarchy in your cluster. Policy tiers are containers that allow different personas in your organisation the definition of based on their role and governed by RBAC. in this example we are defining 3 policy tiers (Platform, Security, Application), which are typical personas involved in policy development.

Navigate to the policy board using the toolbar on the left, and clicking in "Policies":

![policies](img/2-policies.png)

You will see there is only 1 tier (the `default` one). In reality, there will be another tier that you can check if clicking in the `Toggle Tiers` icon in the top right corner ![toggletier](img/1-toggle-tiers.png). These are the rules we applied for the essential Tigera components as part of the previous lab during the installation in step 1.1.5. 

Now, examine, and then apply the manifest file as below, and notice three new tiers will show up (Remember to move to the right lab folder where the manifest is located):

```
cat 2.1-tiers.yaml
```

```
kubectl apply -f 2.1-tiers.yaml
```

Notice the order which represents the order of processing of the tier. 

```
calicoctl get tiers
```
```
NAME           ORDER   
allow-tigera   100     
platform       200     
security       300     
application    400     
default        <nil>    
```

## 2.2. Apply policies to allow dns

Next we will apply policies to allow ingress and egress communication with kubedns. DNS is a vital component of the cluster and is often linked to mucroservices communication issues or slownes. This implement the failsafe rule for kube dns to avoid bricking it as we develop our policies.

```
cat 2.2-ingressallowdns.yaml 
```

Notice the ingress and egress direction of flow with respect to selected endpoints, were ingress are incoming and egress are outgoing. Policy is applied at the Security tier level which implements standard high-level enterprise controls. This avoid lower privileged users from modifying it and the policy order guarantees precedence over other policies in that tier. We are using NetworkPolicies to apply to the kube-system namespace specifically, which hosts kube dns.

```
kubectl create -f 2.2-ingressallowdns.yaml 
```
```
kubectl get networkpolicies.crd -n kube-system
```
```
NAME                                     AGE
security.ingress-allow-pods-to-kubedns   2m7s
```

## 2.3. Apply policies to secure yaobank app

Last step in this lab is to apply Calico network policies to yaobank namespace to secure yaobank services communication. 

```
cat 2.3-yaobank-policies.yaml
```

Notice the order of policies which is only relevant in a sequential policy processing where you expect multiple match in the same tier for selected endpoints. It's not the case here however it's a good practice to follow a logical ordering process to simplify troubleshooting and analysis.

```
kubectl apply -f 2.3-yaobank-policies.yaml
```
```
kubectl get networkpolicies.crd -n yaobank
```
```
NAME                                            AGE
application.ingress-allow-all-to-summary        2s
application.ingress-allow-customer-to-summary   2s
application.ingress-allow-summary-to-database   2s
application.ingress-yaobank-default-deny        2s
```

## 2.4. Testing

Verify that yaobank app is still working properly. Modify the hostname to your own LABNAME.
https://yaobank.<LABNAME>.lynx.tigera.ca/ 

Now verify the endpoints used by thhe yaobank database, and the IP address of the pods in the app2 namespace:

```
kubectl get endpoints database -n yaobank
```
```
NAME       ENDPOINTS          AGE
database   10.48.0.209:2379   120m
```
```
kubectl get pod -n app1
```
```
NAME                               READY   STATUS    RESTARTS   AGE
app1-deployment-5bbfd76f9d-jvmzj   1/1     Running   0          12m
app1-deployment-5bbfd76f9d-mzjzd   1/1     Running   0          12m
```
```
kubectl get pod -n app2 -o wide
```
```
NAME                               READY   STATUS    RESTARTS   AGE    IP            NODE                                         NOMINATED NODE   READINESS GATES
app2-deployment-5fd465d59f-7r79r   1/1     Running   0          122m   10.48.0.211   ip-10-0-1-31.ca-central-1.compute.internal   <none>           <none>
app2-deployment-5fd465d59f-qck2w   1/1     Running   0          122m   10.48.0.85    ip-10-0-1-30.ca-central-1.compute.internal   <none>           <none>
```

We will test the connectivity from one of the pods in the app1 namespace:

```
APP1_POD=$(kubectl get pod -n app1 --no-headers -o name | head -1) && echo $APP1_POD
```
```
kubectl exec -ti $APP1_POD -n app1 -- sh
```

Verify you cannot access the etcd port in the database deployment (use the IP address from the database pod you retrieved earlier):

```
/ # telnet 10.48.0.209:2379
```

However the yaobank rules allow us to access the resource from the `summary` microservice, so your browser should still be able to access yaobank.

Access to any of the app2 pods should be successful (replace the IP for any of the two pods in the namesapce app2 your retrieved before).

```
/ # ping 10.48.0.211
```

Access to external destinations should be successful

```
/ # curl -I https://www.tigera.io
```