
. .connect_test.sh

echo "Adding new service to storefront"
kubectl apply -f ../stage2/2-bank-info.yaml
kubectl wait --timeout=300s --for condition=ready pod -l app=bankinfo -n storefront

POD=$(kubectl get pod -l app=bankinfo -n storefront -o jsonpath="{.items[0].metadata.name}")
echo "**Connectivity from Storefront pod: $POD"
echo ""

#            destNs  srcNs      srcPod
connect_test yaobank storefront bankinfo
