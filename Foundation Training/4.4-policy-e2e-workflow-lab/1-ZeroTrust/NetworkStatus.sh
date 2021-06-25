#echo "Checking Accessibility in my cluster..."

. .connect_test.sh

POD=$(kubectl get pod -l app=attack -n yaobank -o jsonpath="{.items[0].metadata.name}")
echo "**Connectivity from Yaobank pod: $POD"
echo ""

#            destNs  srcNs   srcPod
connect_test yaobank yaobank attacker

#            destNs     srcNs   srcPod
connect_test storefront yaobank attacker
