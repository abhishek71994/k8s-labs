SVC_IP=$(kubectl get svc nginx-service-1 -o jsonpath='{.spec.clusterIP}');
echo -e "\n📋 Testing Connectivity:";
kubectl run --rm -i --restart=Never test --image=curlimages/curl -- curl -s -m 5 $SVC_IP:80 && echo -e "✅ PASS\n" || echo -e "❌ FAIL\n";

echo "📋 Service Count:"; 
kubectl get svc | grep nginx-service | wc -l | awk '{print "  " $1 " services running\n"}';

echo "📋 BGP Routes (sample):";
kubectl exec -n kube-system -c cilium-agent $(kubectl get pod -n kube-system -l k8s-app=cilium -o name | head -n 1) -- cilium service list | grep nginx-service | head -n 3 | awk '{print "  " $0}'; 

kubectl exec -n kube-system -c cilium-agent $(kubectl get pod -n kube-system -l k8s-app=cilium -o name | head -n 1) -- cilium service list | grep 10.96 | head -n 3| awk '{print "  " $0}';
kubectl get svc -o wide | grep nginx-service | head -n 3

echo -e "\n📋 IPTables Check:";

docker exec bgp-demo-worker iptables -t nat -L KUBE-SERVICES -n | grep -q . && echo "  IPTables rules found (unexpected)" || echo -e "  ✅ No KUBE-SERVICES rules (BGP in use)\n"