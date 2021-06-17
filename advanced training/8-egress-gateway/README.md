# 8. Egress Gateway

## 8.0. Introduction

The purpose of this lab is to demonstrate the funciationality of Egress Gateway. In this lab we will:

8.1. Enable per namespace Egress Gateway support
8.2. Deploy an Egress Gateway in *one* namespace
8.3. Enable BGP with upstream routers (Bird) and advertise the Egress Gateway IP Pool
8.4. Test and Verify the communication

## 8.1. Enable egress gateway support on a per-namespace basis.

Patch felix configuration to support per namespace egress gateway support

```
kubectl patch felixconfiguration.p default --type='merge' -p \
    '{"spec":{"egressIPSupport":"EnabledPerNamespace"}}'
```

## 8.1.1. Create IPPool

Create an IP Pool for Egress Gateway Pod

```
kubectl create -f 8.1-egress-pool.yaml
```

## 8.1.2. Apply Calico Enterprise pull secret to egress gateway namespace:

Create a pull secret into egress gateway namespace

```
kubectl create secret generic egress-pull-secret \
  --from-file=.dockerconfigjson=/home/tigera/config.json \
  --type=kubernetes.io/dockerconfigjson -n app1
```

## 8.2. Deploy Egress Gateway

### 8.2.1.EGW

Deploy the Egress gateway with the desire label to be used as an identifier later by Namespace and App Workload for using this Egress Gateway.
In this example the label we are using is `egress-code: red`. This will be referenced in future annotations to stitc the communication end to end.
Please also note the IP Pool assigned to this Egress Gateway. In the cni.projectcalico.org/ipv4pools annotation, the IP Pool can be specified either by its name (e.g. egress-ippool-1) or by its CIDR (e.g. 10.58.0.0/31).


```
kubectl create -f 8.1-egress-gw.yaml
```

## 8.2.2. Connect the namespace to the gateways it should use

```
kubectl annotate ns app1 egress.projectcalico.org/selector='egress-code == "red"'
```

### 8.2.3. Verify both, the POD and Egress Gateway

```
kubectl get pods -n app1 -o wide 
```

## 8.3. BGP

### 8.3.1. BGP configuration on Calico

Deploy the needed BGP config, so we route our traffic to the bastion host through the egress gateway:

```
kubectl create -f 8.1-bgp-conf.yaml
```

### 8.3.2. Check Calico Nodes connect to the bastion host

Our bastion host is simulating our ToR switch, and it should have BGP sessions established to all nodes:

```
sudo birdc show protocols
```

```
BIRD 1.6.8 ready.
name     proto    table    state  since       info
direct1  Direct   master   up     08:15:34    
kernel1  Kernel   master   up     08:15:34    
device1  Device   master   up     08:15:34    
control1 BGP      master   up     13:24:20    Established   
worker1  BGP      master   up     13:24:20    Established   
worker2  BGP      master   up     13:24:20    Established   
```

If you check the routes, you will see the edge gateway is reachable through the worker node where it has been deployed:

```
ip route
```
```
default via 10.0.1.1 dev ens5 proto dhcp src 10.0.1.10 metric 100 
10.0.1.0/24 dev ens5 proto kernel scope link src 10.0.1.10 
10.0.1.1 dev ens5 proto dhcp scope link src 10.0.1.10 metric 100 
10.49.0.0/16 proto bird 
        nexthop via 10.0.1.20 dev ens5 weight 1 
        nexthop via 10.0.1.30 dev ens5 weight 1 
        nexthop via 10.0.1.31 dev ens5 weight 1 
10.58.0.0/31 via 10.0.1.31 dev ens5 proto bird 
```

## 8.4. Verification

### 8.4.1. Test and verify Egress Gateway in action

Open a second browser to your lab (`<LABNAME>.lynx.tigera.ca`) if not already done, so we have an additional terminal to test the egress gateway.

On that terminal, start netcat in the bastion host to listen to an specific port:

```
netcat -nvlkp 7777
```

On the original terminal window, enter to any of the pods in the app1 namespace:

```
APP1_POD=$(kubectl get pod -n app1 --no-headers -o name | head -1) && echo $APP1_POD
```
```
kubectl exec -ti $APP1_POD -n app1 -- sh
```

And try to connect to the port in the bastion host:

```
nc -zv 10.0.1.10 7777
```

Press `ctrl+c` to exit it.

Now on the first terminal on the bastion node, you should see some text saying you connect from the IP of one of the egress gateways, as indicated below.

```
$ netcat -nvlkp 7777
Listening on 0.0.0.0 7777
Connection received on 10.50.0.0 39861
```

Stop the netcat listener process in the bastion host with `^C`.

### 8.4.2. Routing info on the Calico Node where App Workload is running

Login to worker node where the egress gateway and pods were deployed:

```
ssh worker2
```

Observe the routing policy is programmed for the the App workload POD IP

```
ip rule
```

```
0:      from all lookup local
100:    from 10.48.116.155 fwmark 0x80000/0x80000 lookup 250
32766:  from all lookup main
32767:  from all lookup default
```

Confirm that the policy is choosing the egress gateway as the next hold for any source traffic from App workload POD IP

```
ip route show table 250
```

```
default onlink 
        nexthop via 10.50.0.0 dev egress.calico weight 1 onlink 
        nexthop via 10.50.0.1 dev egress.calico weight 1 onlink
```

You can close the second browser tab with the terminal now, as we will not use it for the rest of the labs.

## Conclusion

In this lab we observed how we can successfully setup egress gateway in a calico cluster and share routing information with external routing device over BGP.
