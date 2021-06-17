echo "Disable Istio in Yaobank"
./ToggleIstioYaobank.sh disabled
sleep 20

POD=$(kubectl get pod -l app=attack -n yaobank -o jsonpath="{.items[0].metadata.name}")
echo Attack pod: $POD

#kubectl exec -ti $POD -n yaobank -c attacker -- curl --connect-timeout 5 -v http://$(kubectl get globalnetworkset threatfeed.feodo-tracker  -o jsonpath='{.spec.nets[1]}')
#kubectl exec -ti $POD -n yaobank -c attacker -- curl --connect-timeout 5 -v http://$(kubectl get globalnetworkset threatfeed.feodo-tracker  -o jsonpath='{.spec.nets[2]}')
#kubectl exec -ti $POD -n yaobank -c attacker -- curl --connect-timeout 5 -v http://$(kubectl get globalnetworkset threatfeed.feodo-tracker  -o jsonpath='{.spec.nets[3]}')
kubectl exec -ti $POD -n yaobank -c attacker -- curl --connect-timeout 5 -v http://$(kubectl get globalnetworkset threatfeed.feodo-tracker  -o jsonpath='{.spec.nets[4]}')
kubectl exec -ti $POD -n yaobank -c attacker -- curl --connect-timeout 5 -v http://$(kubectl get globalnetworkset threatfeed.feodo-tracker  -o jsonpath='{.spec.nets[5]}')

echo "Executing access to restricted Tigera resource"
kubectl exec -ti $POD -n yaobank -c attacker -- curl --connect-timeout 3 www.tigera.io
kubectl exec -ti $POD -n yaobank -c attacker -- curl --connect-timeout 3 tigera.io

echo "Executing access to restricted Cloud resource"
kubectl exec -ti $POD -n yaobank -c attacker -- bash -c "export PGPASSWORD=%admin4321%; /usr/bin/psql --host=bgdbxydemo.cmapoe0bxbtn.us-east-1.rds.amazonaws.com  --port=5432 --username=demo123 --dbname=bgdemo123 -c 'select 1'"
kubectl exec -ti $POD -n yaobank -c attacker -- bash -c "export PGPASSWORD=%admin4321%; /usr/bin/psql --host=bgdbxydemo.cmapoe0bxbtn.us-east-1.rds.amazonaws.com  --port=5432 --username=demo123 --dbname=bgdemo123 -c 'select 1'"
kubectl exec -ti $POD -n yaobank -c attacker -- bash -c "export PGPASSWORD=%admin4321%; /usr/bin/psql --host=bgdbxydemo.cmapoe0bxbtn.us-east-1.rds.amazonaws.com  --port=5432 --username=demo123 --dbname=bgdemo123 -c 'select 1'"
kubectl exec -ti $POD -n yaobank -c attacker -- bash -c "export PGPASSWORD=%admin4321%; /usr/bin/psql --host=bgdbxydemo.cmapoe0bxbtn.us-east-1.rds.amazonaws.com  --port=5432 --username=demo123 --dbname=bgdemo123 -c 'select 1'"
kubectl exec -ti $POD -n yaobank -c attacker -- bash -c "export PGPASSWORD=%admin4321%; /usr/bin/psql --host=bgdbxydemo.cmapoe0bxbtn.us-east-1.rds.amazonaws.com  --port=5432 --username=demo123 --dbname=bgdemo123 -c 'select 1'"
kubectl exec -ti $POD -n yaobank -c attacker -- bash -c "export PGPASSWORD=%admin4321%; /usr/bin/psql --host=bgdbxydemo.cmapoe0bxbtn.us-east-1.rds.amazonaws.com  --port=5432 --username=demo123 --dbname=bgdemo123 -c 'select 1'"
kubectl exec -ti $POD -n yaobank -c attacker -- bash -c "export PGPASSWORD=%admin4321%; /usr/bin/psql --host=bgdbxydemo.cmapoe0bxbtn.us-east-1.rds.amazonaws.com  --port=5432 --username=demo123 --dbname=bgdemo123 -c 'select 1'"
kubectl exec -ti $POD -n yaobank -c attacker -- bash -c "export PGPASSWORD=%admin4321%; /usr/bin/psql --host=bgdbxydemo.cmapoe0bxbtn.us-east-1.rds.amazonaws.com  --port=5432 --username=demo123 --dbname=bgdemo123 -c 'select 1'"
kubectl exec -ti $POD -n yaobank -c attacker -- bash -c "export PGPASSWORD=%admin4321%; /usr/bin/psql --host=bgdbxydemo.cmapoe0bxbtn.us-east-1.rds.amazonaws.com  --port=5432 --username=demo123 --dbname=bgdemo123 -c 'select 1'"
kubectl exec -ti $POD -n yaobank -c attacker -- bash -c "export PGPASSWORD=%admin4321%; /usr/bin/psql --host=bgdbxydemo.cmapoe0bxbtn.us-east-1.rds.amazonaws.com  --port=5432 --username=demo123 --dbname=bgdemo123 -c 'select 1'"
echo "Executing IP sweep to cluster pod IP net 172.20.32.0/19"

echo "Executing port sweep in the cluster"
kubectl exec -ti $POD -n yaobank -c attacker -- nmap -p45 -v 172.20.32.0/19

echo "Attack kill chain activity detected!!"
