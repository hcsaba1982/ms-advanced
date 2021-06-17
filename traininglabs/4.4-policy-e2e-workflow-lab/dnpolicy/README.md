### DNS Policy Example

### 1. Create baseline tier and policies

We'll create policies in a new whitelist tier for ns1-open

```
kubectl apply -f whitelist-baseline-policies.yaml
```


### 2. Try to ping different DNS names

```
kubectl exec -it  -n ns1-open centos-open bash
	curl www.google.com
	curl www.docker.com
```

These should fail, since egress is blocked

### 3. Create a whitelist policy using DNS

Lets whitelist the CentOS pod to allow it to access www.docker.com

```
kubectl apply -f allow-docker-com.yaml
kubectl exec -it -n ns1-open centos-open bash
	curl www.google.com
	curl www.docker.com
```

The first should fail, the second ping should succeed

