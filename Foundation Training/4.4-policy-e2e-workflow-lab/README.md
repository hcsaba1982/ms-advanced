## 4.4. Network Policy - Advanced Lab

This labs walks you through common use security cases that you can implement with Calico Enterprise.

In this lab you will:
4.4.1. xyz
4.4.2. xyz
4.4.3. xyz
4.4.4. xyz

### 4.4.0. Before you begin



### 4.4.1. Zero-trust security

In this section, we will review how Calico enterprise helps establish zone-based policies inside your cluster. We will enforce the capability in 4 stages. We will start with simulating malware propagation with the default configuration then we'll setup firewall zones in stages to prevent malware propagation and data theft at L4-L7 layers.





Then we will trigger a rogue system. The rogue system will be identified by a threshold-based trigger set up in prometheus (will not be part of lab). We will then quarantine the rogue system after examining the behavior.

[TBD] In Threat detection and prevention, we demonstrate how Tigera Secure detects and protects your cluster from a cyber kill chain hack. We start with a security alert for malicious outbound access, and investigate the activities of the attacker. That includes anomaly detection and data theft. We will then enforce threat prevention to prevent the C&C connections. 

The attack kill chain also exposes a policy control gap in egress traffic. We remediate that using DNS policy in 4th use case. It hardens our cluster, ensuring a default-deny and permits access for specific pods.

And finally in the last use case, we will build inventory and compliance reports.


## Zone-based policy

Head over to 1-ZeroTrust folder.

Let’s see the security of our cluster in default state. And then we build out the security from the ground up, just like you build your network.

./NetworkStatus.sh

So you can see that every service is able to connect to every other service, irrespective of namespace. Of course, it is not acceptable. If we wear the security architect’s hat, we’ve assets of different business values. So we need to group them in zones. Commonly used zones are DMZ, Trusted and Restricted. Let’s apply the zones to the cluster and see what happens.

./SecureFirewallZones.sh

./NetworkStatus.sh

So now we can see that we’ve compartmentalized the namespace traffic. So a service in frontend cannot speak to service in Yaobank. Or a Customer service cannot speak to Database service. Of course, DMZ is open access for all services. This is very powerful. You achieve this by simply building your policies on labels. And then apply those labels to the pods. This is declarative policy and have the power to cut down your firewall rules our factor of 10 or more. Let us see what attacker has access to.

So this makes sense. Attacker is able to access database as they are in the same zone.

Businesses evolve, so security should never be a bottleneck for an agile business. Storefront team want to roll out a Bank-Info service. This service will need to be able to fetch customer data from Database service of YaoBank. 

./NewServiceStorefront.sh

So w/ just 1 policy, now my bank info service can get data from Database. Here is the important part - this policy is controlled by security admin, and NOT by storefront or yaobank admin. We achieve this by a capability “policy tiers” in Calico Enterprise. As a security admin, this makes it extremely simple to offload your firewall rules to Calico Enterprise, and also segregate controls for agile development.

So now the firewall zoning looks good and we’ve segregation of control. 


## Rogue workload detection and quarantine

Head over to 2-Incident. Trigger the rogue workload from  ./DeployRogue.sh.

While we will skip the prometheus alerting part, it’s worth reviewing the docs (doc.tigera.io, search for prometheus alerting). 

For the purpose of this lab, let us review the stats (policy page) and flow visualization.

You can then quarantine the rogue using ./QuarantineRogue.sh


## Cyber Kill Chain

Let’s see how Calico Enterprise enables you to detect/protect from a typical cyber kill chain. I had triggered a set of activities from the attacker.

./demo-killchain-attacks.sh (you must have done it before)

Go to Calico Enterprise alerts page. It has a new alert (suspicious IP connection). It’s coming from the attack pod. This is unique about Calico Enterprise. If you use a perimeter firewall, you will not have the insight into the kubernetes context. We also see that Calico Enterprise has allowed the traffic. Let’s investigate what else the attacker is doing. 

Go to “anomaly explorer tab”... the attacker also has scanned the cluster - which is an obvious anomaly.

Go to “kibana flow logs tab”... we see that the attacker is trying to connect to restricted resources outside my cluster - the database (inside my org), and an external resource (tigera.io). This is very typical of a cyber kill chain and with Calico Enterprise, we’re able to identify these activities.

Calico Enterprise  provides threat prevention capability. So the immediate thing to do is first enable threat prevention so that attacker cannot connect to malicious C&C. I am going to create the policy to enable threat prevention.

The attack kill chain also exposed a policy control gap in egress traffic. We had cloud and external resources which were open to attacker!! Let us see how we can remediate. I am going to enable default deny for all outbound traffic from my applications. Then I am going to permit access to database and tigera resource only for summary and bankinfo services.

./remediate-threat-feed.sh

Let’s see if our attacker can connect to restricted resources outside my cluster.

./check-attacker-C_C.sh

You can see that attacker is completely blocked. Calico Enterprise alerts show that the C&C connections are denied. DNS policy controls show how we hardened our cluster for granular access to services outside the cluster. You will also notice that we’ve created these policies in a privileges tier.. So the admins for yaobank or storefront cannot modify those. This enables you bring you firewall controls from perimeter to Calico, while still retaining the administrative boundaries.



