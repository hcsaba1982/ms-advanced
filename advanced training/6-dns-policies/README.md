# 6. Calico DNS Policy

In this lab, we will implement dns policies to match fqdn in policies.

Steps:
5.1. Define globalnetworkset for trusted repos
5.2. Implement dns globalnetworkpolicies 
5.3. Define networkset for app1 trusted domains
5.4. Implement app1 ds networkpolicies
5.5. Test

## 6.1. Globalnetworkset for trusted repos

DNS policies allow for securing egress communication to trusted destinations based on fqdn. Calico implements DNS policies by listening to DNS replies for domains defined in globalnetworkset (gns) and networkset (ns) (and used in policies), and populates ip address information in ipset at the kernel level that is referenced in iptables. It is recommended to define all external endpoints (fqdn or ip addresses) in gns and ns, depending on the scope (global vs namespace). This is a key recommendation for optimizing policy processing and for scalability. Avoid overlap in gn and ns ip addresses. Avoid using individual ip addresses in policies.

Note that Calico allows for the tweaking of DNS ttl values to account for race condition at ttl expiry (removing ipset ipaddress at ttl expiry before app resend dns request to refresh ttl). Enhancements to DNS policies will allow the automatic population of fqdn ip addresses.

In lab 3, we deployed a series of network sets as destinations for external communication. One of those sets (`trusted-repos`) uses fqdns instead of IP addresses, and make use of dns policies. Let's inspect it:

```
calicoctl get globalnetworkset trusted-repos -o yaml
```

## 6.2. Define networkset for app1 trusted domains

Now we will move to implementing dns policies specific to app1. The first step is to define a networkset including app1 trusted domains.

```
cat 5.3-networkset.yaml
```

Notice the namespace metadata config, defining the scope of the networkset to app1 namespace.

```
kubectl apply -f 5.3-networkset.yaml
```

## 6.3. Implement app1 ds networkpolicies

The last step is to implement a networkpolicy to app1 namespace allowing access to trusted domains.

```
cat 5.4-app1-network-policies.yaml
```

Notice the ingress deny action for app1. This implies that pod1 is allowed egress communication with its own trusted domains, in addition to global trsuted repos that we have previously defined.

```
kubectl apply -f 5.4-app1-network-policies.yaml
```

## 6.4. Test

Test communication from app1 and app2. As defined in app1 should have access to trusted repos and domains while app2 should only have access to trusted repo.

```
APP1_POD=$(kubectl get pod -n app1 --no-headers -o name | head -1) && echo $APP1_POD
```
```
kubectl exec -it $APP1_POD -n app1 -- sh
```

Check you can reach github, but not other domains:

```
/ # nc -zv github.com 80
github.com (140.82.114.4:80) open
/ # nc -zv www.google.com 80
```

