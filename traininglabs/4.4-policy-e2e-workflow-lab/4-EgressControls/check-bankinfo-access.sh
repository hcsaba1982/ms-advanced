POD2=$(kubectl get pod -l app=bankinfo -n storefront -o jsonpath="{.items[0].metadata.name}")

kubectl exec -ti $POD2 -n storefront -c bankinfo -- bash -c "export PGPASSWORD=%admin4321%;PGCONNECT_TIMEOUT=3 /usr/bin/psql --host=bgdbxydemo.cmapoe0bxbtn.us-east-1.rds.amazonaws.com  --port=5432 --username=demo123 --dbname=bgdemo123 -c 'select 1'"
kubectl exec -ti $POD2 -n storefront -c bankinfo -- bash -c "export PGPASSWORD=%admin4321%;PGCONNECT_TIMEOUT=3 /usr/bin/psql --host=18.232.196.29  --port=5432 --username=demo123 --dbname=bgdemo123 -c 'select 1'"
