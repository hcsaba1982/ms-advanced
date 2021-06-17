## 4.3. Network Policy - Advanced Lab

This is the 2nd lab in a series of labs exploring network policies.

In this lab you will:
4.3.1. Create Egress Lockdown policy as a Security Admin for the cluster
4.3.2. Grant selective Internet access
4.3.3. Protect the Host
4.3.4. Add Policy for Kubernetes NodePorts

### 4.3.0. Before you begin

This lab builds on the previous lab and cannot be run independently. So if you haven't already done so, please go back and complete lab 4.2.
In the K8s Network Policy deployed in the Policy fundamentals lab, the developer's policy allows all pod egress, even to the Internet.


### 4.3.1. Create Egress Lockdown policy as a Security Admin for the cluster

This lab guides you through the process of deploying a egress lockdown policy in our cluster.
In Lab4.2, we have applied a policy that allows all pod access. Best-practices call for a restrictive policy that allows minimal access and denies everything else.
Let's first start with verifying connectivity with the configuration of Lab4.2 already applied.

#### 4.3.1.1. Confirm that pods are able to initiate connections to the Internet

Access the customer pod.

```
CUSTOMER_POD=$(kubectl get pod -l app=customer -n yaobank -o jsonpath='{.items[0].metadata.name}')
kubectl exec -ti $CUSTOMER_POD -n yaobank -c customer bash
ping -c 3 8.8.8.8
curl -I www.google.com
exit
```

This succeeds since the policy in place allows full internet access.

Let's now create a Calico GlobalNetworkPolicy to restrict Egress to the Internet to only pods that have the ServiceAccount that is labeled  "internet-egress = allowed".

#### 4.3.1.2. Examine and apply the network policy

Examine the policy before applying it. While Kubernetes network policies only have Allow rules, Calico network policies also support Deny rules. As this policy has Deny rules in it, it is important that we set its precedence higher than the K8s policy Allow rules. To do this we specify `order`  value of 600 in this policy, which gives it higher precedence than the k8s policy (which does not have the concept of policy precedence, and is assigned a fixed order value of 1000 by Calico). 

```
more 4.3-egress-lockdown.yaml

apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: egress-lockdown
spec:
  order: 600
  selector: ''
  types:
  - Egress
  egress:
    - action: Allow
      source:
        serviceAccounts:
          selector: internet-egress == "allowed"
      destination: {}
    - action: Deny
      source: {}
      destination:
        notNets:
          - 10.48.0.0/16
          - 10.49.0.0/16
          - 10.50.0.0/24
          - 10.0.0.0/24

```
Notice the notNets destination parameter that excludes known cluster networks from the deny rule. This is another feature specific to calico that allows matching based on ip subnets.
Now let's apply the policy.
```
calicoctl apply -f 4.3-egress-lockdown.yaml
```

#### 4.3.1.3. Verify access the Internet

```
kubectl exec -ti $CUSTOMER_POD -n yaobank -c customer bash
ping -c 3 8.8.8.8
curl -I www.google.com
```

These commands should fail - pods are now restricted to only accessing other pods and nodes within the cluster. You may need to terminate the command with CTRL- and exit back to your node.
```
exit
```

### 4.3.2. Grant selective Internet access

Now let's take the case where there is a legitimate reason to allow connections from the Customer pod to the internet. As we used a Service Account label selector in our egress policy rules, we can enable this by adding the appropriate label to the pod's Service Account.

#### 4.3.2.1. Add "internet-egress=allowed" to the Service Account

```
kubectl label serviceaccount -n yaobank customer internet-egress=allowed
```

#### 4.3.2.2. Verify the pod can now access the internet
```
kubectl exec -ti $CUSTOMER_POD -n yaobank -c customer bash
ping -c 3 8.8.8.8
curl -I www.google.com
exit
```

Now you should find that the customer pod is allowed Internet Egress, but other pods (like Summary and Database) are not.

#### 4.3.2.3. Managing trust across teams

There are many ways of dividing responsibilities across teams using Kubernetes RBAC.

Let's take the following case:
* The secops team is responsible for creating Namespaces and Services accounts for dev teams. Kubernetes RBAC is setup so that only they can do this.
* Dev teams are given Kubernetes RBAC permissions to create pods in their Namespaces, and they can use, but not modify any Service Account in their Namespaces.

In this scenario, the secops team can control which teams should be allowed to have pods that access the internet.  If a dev team is allowed to have pods that access the internet then the dev team can choose which pods access the internet by using the appropriate Service Account. 

This is just one way of dividing responsibilities across teams.  Pods, Namespaces, and Service Accounts all have separate Kubernetes RBAC controls and they can all be used to select workloads in Calico network policies.

### 4.3.3. Protect the Host

Thus far, we've created policies that protect pods in Kubernetes. However, Calico Policy can also be used to protect the host interfaces in any standalone Linux node (such as a baremetal node, cloud instance or virtual machine) outside the cluster. Furthermore, it can also be used to protect the Kubernetes nodes themselves.

The protection of Kubernetes nodes themselves highlights some of the unique capabilities of Calico - since this needs to account for various control plane services (such as the apiserver, kubelet, controller-manager, etcd, and others. In addition, one needs to also account for certain pods that might be running with host networking (i.e., using the host IP address for the pod) or using hostports. To add an additional layer of challenge, there are also various services (such as Kubernetes NodePorts) that can take traffic coming to reserved port ranges in the host (such as 30000-32767) and NAT it prior to forwarding to a local destination (and perhaps even SNAT traffic prior to redirecting it to a different worker node). 

Lets explore these more advanced scenarios, and how Calico policy can edtablish the right policies.

#### 4.3.3.1. Observe that Kubernetes Control Plane has been left exposed by Kubeadm

Lets start by seeing how the default cluster deployment have left some control plane services exposed to the world.

Run the command below from the standalone host (master):

```
curl -v 10.0.0.10:2379
```

This should succeed - i.e., the Kubernetes cluster's ETCD store is left exposed for attacks, along with the rest of the control plane. Not good!!


#### 4.3.3.2. Create Network Policy for Hosts
Lets create some host endpoint policies for the kubernetes master node and worker nodes
Examine the policy first before applying it.

```
more 4.3-global-host-policy.yaml


apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: k8s-master2master-allowed-ports
spec:
  selector: k8s-master == "true"
  order: 300
  ingress:
  - action: Allow
    protocol: TCP
    source:
      selector: k8s-master == "true"
    destination:
      ports: ["2379:2380", 4001, "10250:10256", 9099, 6443 ]
  egress:
  - action: Allow

---
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: k8s-outside2master-allowed-ports
spec:
  selector: k8s-master == "true"
  order: 350
  ingress:
  - action: Allow
    protocol: TCP
    destination:
      ports: [10250, 6443]
  - action: Allow
    protocol: UDP
    destination:
      ports: [53]
  egress:
  - action: Allow


---

apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: k8s-outside2worker-allowed-ports
spec:
  selector: k8s-worker == "true"
  order: 400
  ingress:
  - action: Allow
    protocol: TCP
    destination:
      ports: [10250, 10256 ]
  egress:
  - action: Allow
---


apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: block-k8s-nodeports
spec:
  selector: k8s-worker == "true"
  order: 450
  applyOnForward: true
  preDNAT: true
  ingress:
  - action: Deny
    protocol: TCP
    destination:
      ports: ["30000:32767"]
  - action: Deny
    protocol: UDP
    destination:
      ports: ["30000:32767"]

```

```
calicoctl apply -f 4.3-global-host-policy.yaml
```

We have created the policy that locks down the control plane such that the worker nodes only have kubelet exposed, and the master nodes only have important services (like Etcd) accessible only from other master nodes.

#### 4.3.3.3. Create Host Endpoints

Before creating the Host Endpoints in k8s, Calico cannot enforce policies on hosts. Let's now create the Host Endpoints themselves, allowing Calico to start policy enforcement on the nodes ethernet interface. While we're at it, lets also lockdown nodePorts.

Eaxmine the policy first before applying it.

```
more 4.3-host-endpoint.yaml

apiVersion: projectcalico.org/v3
kind: HostEndpoint
metadata:
  name: master1
  labels:
    k8s-master: true
    k8s-worker: true
spec:
  interfaceName: ens160
  node: master1
  expectedIPs: ["10.0.0.10"]
---
apiVersion: projectcalico.org/v3
kind: HostEndpoint
metadata:
  name: worker1
  labels:
    k8s-worker: true
spec:
  interfaceName: ens160
  node: worker1
  expectedIPs: ["10.0.0.11"]
---
apiVersion: projectcalico.org/v3
kind: HostEndpoint
metadata:
  name: worker2
  labels:
    k8s-worker: true
spec:
  interfaceName: ens160
  node: worker2
  expectedIPs: ["10.0.0.12"]

```


```
calicoctl apply -f 4.3-host-endpoint.yaml
```


#### 4.3.3.4. Now lets attempt to attack etcd from the standalone host. Run the curl again from the standalone host (host1):

```
curl -v  -m 5 10.0.0.10:2379
```

This time the curl should fail, and timeout after 5 seconds. 
We have successfully locked down the Kubernetes control plane to only be accessible from relevant nodes.


### 4.3.4. Add Policy for Kubernetes NodePorts

#### 4.3.4.1. Verify you cannot access yaobank frontend
Now open up a new incognito browser tab (to ensure that a new connection is attempted from your browser) and try to access the Yaobank service again. It should fail since our host protection explicitly locked down nodePorts too. Let's now allow specific nodePorts.

#### 4.3.4.2. Examine and Apply the policy

```
more 4.3-global-host-policy-allow.yaml

apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: allow-yaobank-nodeport
spec:
  order: 425
  selector: k8s-worker == "true"
  applyOnForward: true
  preDNAT: true
  ingress:
    - action: Allow
      protocol: TCP
      destination:
        ports: [30180]
  types:
    - Ingress
---
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: allow-desired-clustervips
spec:
  order: 425
  selector: k8s-worker == "true"
  applyOnForward: true
  preDNAT: true
  ingress:
    - action: Allow
      destination:
        nets:
          - 10.49.0.0/16
  types:
    - Ingress

---

apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: allow-desired-externalvips
spec:
  order: 425
  selector: k8s-worker == "true"
  applyOnForward: true
  preDNAT: true
  ingress:
    - action: Allow
      destination:
        nets:
          - 10.50.0.0/24
  types:
    - Ingress

---

apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: allow-desired-podcidrs
spec:
  order: 425
  selector: k8s-worker == "true"
  applyOnForward: true
  preDNAT: true
  ingress:
    - action: Allow
      destination:
        nets:
          - 10.48.0.0/16
  types:
    - Ingress

```


```
calicoctl apply -f 4.3-global-host-policy-allow.yaml
```

#### 4.3.4.3. Verify access
Now try to access the Yaobank app from your browser again. This should work properly. 

This illustrates the capabilities of Calico for enabling advanced network security across your Kubernetes cluster, including control plane, the master and worker nodes, hostports and host-networked pods as well as services and nodePorts! 

> __Congratulations! You have completed your Calico advanced policy lab.__
