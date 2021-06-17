#echo "Checking Accessibility in my cluster..."

which jq &>/dev/null
if [ $? -ne 0 ]; then
  echo "jq is not installed please install it first"
  exit 1
fi

RED='\033[0;31'
GREEN='\033[0;32'
NC='\033[0m'

function connect_test {
  dstNs=$1
  srcNs=$2
  srcPod=$3

  while IFS= read -r pod
  do
    ns=$(echo "$pod" | awk '{print $1}')
    name=$(echo "$pod" | awk '{print $2}')
    ip=$(echo "$pod" | awk '{print $3}')
    lbl=$(echo "$pod" | awk '{print $4}')
    echo -n "${ns}/${lbl}/${name}/${ip}:   "
    kubectl exec $POD -n $srcNs -c $srcPod -- ping -W 1 -qc1 $ip 2>&1 | awk -F'/' 'END{ print (/^rtt/? "\033[32mOK\033[0m "$5" ms":"\033[31mFAIL\033[0m") }'
  done <<< "$(kubectl get pods -n $dstNs -o json | \
  	jq '.items[] | "\(.metadata.namespace) \(.metadata.name) \(.status.podIP) \(.metadata.labels."fw-zone")"' | \
  	grep -v attack | grep -v logging | \
	grep -v '^[[:space:]]*$' | sed -e 's|"||g')"
}

