## 4.2. Network Policy - Fundamentals

This is the 2nd lab lab exploring Calico network policies and explores use cases of NetworkPolicy and GlobalNetworkPolicy for pod and services communication.

In this lab you will:
4.2.1. Simulate a compromise
4.2.2. Create Kubernetes Network Policy limiting access
4.2.3. Create a Global Default Deny and allow Authorized DNS
4.2.4. Create a network policy to the rest of the sample application

### 4.2.0. Before you begin

In this lab, we will be using the sample application Yaobank.
If you haven't already done so, please deploy the YAO Bank sample application as described in Lab1.

Make sure you are in the right directory:

`cd TRAININGWORKBOOKS/4.2-policy-fundamentals-lab`

Change `TRAININGWORKBOOKS` to the directory where you have clone the training labs repository.

```
calicoctl delete -f ./lab_manifests/4.1-customer2summary.yaml
```

```
kubectl apply -f ../1-install-calico-k8s-lab/lab_manifests/1-yaobank.yaml
kubectl get svc -n yaobank
kubectl get pods -n yaobank -o wide
```

### 4.2.1. Simulate a compromise

First, let's start by simulating a pod compromise where the attacker is attempting to access the database from the compromised pod. We can simulate a compromise of the customer pod by just exec'ing into the pod and attempting to access the database directly from there.

#### 4.2.1.1. Exec into the Customer pod

Determine the customer pod ip address and assign it to a variable so that we can reference it later on.  

```
CUSTOMER_POD=$(kubectl get pod -l app=customer -n yaobank -o jsonpath='{.items[0].metadata.name}')
echo $CUSTOMER_POD
```
Verify that the output correctly references the pod.
Execute into the pod to simulate a compromise.

```
kubectl exec -ti $CUSTOMER_POD -n yaobank -c customer -- bash
```
You are now logged in and ready to launch the attack.

#### 4.2.1.2. Access the Database
From within the customer pod, attempt to access the database directly. The attack will succeed, and the balance of all users will be returned. This is expected as there are no policies limiting access yet.

```
curl http://database:2379/v2/keys?recursive=true | python -m json.tool
```

Now, let's exit the pod and put some network policies in place.
```
exit
```

### 4.2.2. Create Kubernetes Network Policy limiting access

We can use a Kubernetes Network Policy to protect the Database.

#### 4.2.2.1. Examine and apply the network policy manifest
``` 
more ./lab_manifests/4.2-k8s-network-policy-yaobank.yaml

kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: database-policy
  namespace: yaobank
spec:
  podSelector:
    matchLabels:
      app: database
  ingress:
    - from:
      - podSelector:
          matchLabels:
            app: summary
      ports:
      - protocol: TCP
        port: 2379
```

The policy allows access to the database on TCP port 2379 strictly from summary pods.
Let's apply the policy before we re-test the same attack again.

```
kubectl apply -f ./lab_manifests/4.2-k8s-network-policy-yaobank.yaml
```

#### 4.2.2.2. Try the attack again
Repeat the attack commands in Section 4.2.1 above. This time the direct database access should fail, however, the customer frontend access from your browser should still work.

```
# Execute bash command in customer container
kubectl exec -ti $CUSTOMER_POD -n yaobank -c customer bash
```

```
curl http://database:2379/v2/keys?recursive=true | python -m json.tool
```

The curl will be blocked and return no data.  You may need to CTRL-C to terminate the command.  Then remember to exit the pod exec and return to the host terminal.
```
exit
```

### 4.2.3. Create a Global Default Deny and allow Authorized DNS

Now, let's introduce a Calico default deny GlobalNetworkPolicy which applies throughout our cluster. 

#### 4.2.3.1. Examine and apply the default deny policy
```
more ./lab_manifests/4.2-globaldefaultdeny.yaml

apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: default-deny
spec:
  selector: all()
  types:
  - Ingress
  - Egress

```

Now, let's apply policy and verify the impact.

```
calicoctl apply -f ./lab_manifests/4.2-globaldefaultdeny.yaml

```

### 4.2.3.3. Verify default deny policy

In Step 4.2.2 above we only defined network policy for the Database. The rest of our pods should now be hitting default deny since there's no policy defined matching them.  

Lets try to see if basic connectivity works by logging into the customer pod and doing some tests.

```
kubectl exec -ti $CUSTOMER_POD -n yaobank -c customer -- bash
```

```
dig www.google.com
```

That should fail, timing out after around 15s, because we do not have a policy in placing allowing DNS.
Remember to exit from the kubectl exec of the customer pod by typing `exit`.

```
exit
```

#### 4.2.3.4. Allow DNS

Now, let's examine and apply a  policy allowing DNS to the cluster internal kube-dns, and allowing kube-dns to communicate with anything.

```
more ./lab_manifests/4.2-globalallowdns.yaml

apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: dns-allow
spec:
  order: 600
  selector: all()
  egress:
  - action: Allow
    protocol: UDP
    destination:
      ports:
      - 53
      selector: k8s-app == "kube-dns"
  - action: Allow
    protocol: TCP
    destination:
      ports:
      - 53
      selector: k8s-app == "kube-dns"
  - action: Deny
    protocol: UDP
    destination:
      ports:
      - 53
  - action: Deny
    protocol: TCP
    destination:
      ports:
      - 53
---
apiVersion: projectcalico.org/v3
kind: NetworkPolicy
metadata:
  name: kubedns-allow-all
  namespace: kube-system
spec:
  order: 500
  selector: k8s-app == "kube-dns"
  egress:
  - action: Allow
  ingress:
  - action: Allow
    protocol: UDP
    destination:
      ports:
      - 53
  - action: Allow
    protocol: TCP
    destination:
      ports:
      - 53
```

The global policy allows all pods egress access to kube-dns and denies egress DNS requests to other DNS servers.  
The network policy allows ingress DNS requests to kube-dns.
Notice the policy order which is a functionnality of Calico that allows a deterministic sequential processing of policies.

Now, let's apply the policy and examine the impact. 

```
calicoctl apply -f ./lab_manifests/4.2-globalallowdns.yaml
```

Now repeat the same test and DNS lookups should be successful.

```
kubectl exec -ti $CUSTOMER_POD -n yaobank -c customer -- bash
```

```
dig www.google.com
```

Remember to exit from the kubectl exec of the customer pod by typing `exit`.
```
exit
```

### 4.2.4. Create a network policy to the rest of the sample application

We've now defined a default deny across all of the cluster, plus allowed DNS queries to kube-dns (CoreDNS). We also defined a specific policy for the `database` in section 4.2. 
But we haven't yet defined policies for the `customer` or `summary` pods.

#### 4.2.4.1. Verify Frontend is not accessible

Try to access the Yaobank front end from your browser. The Yaobank app should timeout since we haven't created a policy for the `customer` and `summary` pods. So, in this case we are actually matching the default deny rule. 

### 4.2.4.2. Create policy for the remaining pods

Let's examine and apply a policy for all the Yaobank services.
```
more ./lab_manifests/4.2-more-yaobank-policy.yaml

kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: summary-policy
  namespace: yaobank
spec:
  podSelector:
    matchLabels:
      app: summary
  ingress:
    - from:
      - podSelector:
          matchLabels:
            app: customer
      ports:
      - protocol: TCP
        port: 80
  egress:
    - to: []

---

kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: customer-policy
  namespace: yaobank
spec:
  podSelector:
    matchLabels:
      app: customer
  ingress:
    - ports:
      - protocol: TCP
        port: 80
  egress:
    - to: []
```

Notice that the egress rules are excessively liberal, allowing outbound connection to any destination. While this may be required for some workloads, in most cases specific restrictive rules are required to limit cluster access. We will look at how this can be locked down further by the cluster operator or security admin in the next module.

```
kubectl apply -f ./lab_manifests/4.2-more-yaobank-policy.yaml
```

#### 4.2.4.3. Verify everything is now working
Now try accessing the Yaobank front end from the browser, it should work again. By defining the cluster wide default deny we've forced the user to follow best practices and define network policy for all the necessary microservices.


> __Congratulations! You have completed you fundamental Calico policies lab.__
