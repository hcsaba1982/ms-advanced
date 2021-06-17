POD1=$(kubectl get pod -l app=summary -n yaobank -o jsonpath="{.items[0].metadata.name}")

echo "Executing access to restricted Tigera resource"
kubectl exec -ti $POD1 -n yaobank -c summary -- curl -v --connect-timeout 3 www.tigera.io
kubectl exec -ti $POD1 -n yaobank -c summary -- curl -v --connect-timeout 3 tigera.io

