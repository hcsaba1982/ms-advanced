#kubectl apply -f ../stage2/feodo-block-policy.yaml
kubectl apply -f ../stage2/default-deny-egress-yaobank.yaml
kubectl apply -f ../stage2/default-deny-egress-storefront.yaml
kubectl apply -f ../stage2/restricted-resource-allow-policy.yaml

POD=$(kubectl get pod -l app=attack -n yaobank -o jsonpath="{.items[0].metadata.name}")
POD1=$(kubectl get pod -l app=summary -n yaobank -o jsonpath="{.items[0].metadata.name}")
POD2=$(kubectl get pod -l app=bankinfo -n storefront -o jsonpath="{.items[0].metadata.name}")

kubectl label pod $POD1 -n yaobank confidentialAccessPermitted=true --overwrite
kubectl label pod $POD2 -n storefront confidentialAccessPermitted=true --overwrite

