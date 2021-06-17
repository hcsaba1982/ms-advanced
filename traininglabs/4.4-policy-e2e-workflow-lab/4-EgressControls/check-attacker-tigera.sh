POD=$(kubectl get pod -l app=attack -n yaobank -o jsonpath="{.items[0].metadata.name}")

echo "Executing access to restricted Tigera resource"
kubectl exec -ti $POD -n yaobank -c attacker -- curl -v --connect-timeout 3 www.tigera.io
#kubectl exec -ti $POD -n yaobank -c attacker -- curl --connect-timeout 3 23.185.0.2
