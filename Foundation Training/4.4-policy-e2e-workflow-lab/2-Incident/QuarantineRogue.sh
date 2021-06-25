POD=$(kubectl get pod -l app=rogue -n storefront -o jsonpath="{.items[0].metadata.name}")
kubectl label pod $POD -n storefront quarantine=true

