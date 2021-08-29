# Consul Cluster and Vault Cluster

This tutorial describes how to create a Consul Cluster and a Vault Cluster.

On top of that, I'm going to show how to configure Vault to use the Consul as storage backend and as a bonus how to generate dynamic tokens for Consul agents using Vault.

I will not get in details about the Docker Compose configuration but it will use a non-default network to make it easier to use names instead of IP addresses in the configuration.

All files are fully configurated but I will mention the parts that you need to add, so REMOVE or COMMENT these parts before starting the tutorial, otherwise, it will not work.

I'm also showing you how to create the tokens, so simply replace them in the configuration according to you move forward in the tutorial.

All Policies are super generic and are intended only to show how things work, you can check the references and create more specific policies.

## Configuring the Consul Cluster 

0. Clone this repo and access the top level directory.
* You don't need to build any image, the `docker-compose` commands will build it if necessary.
* The certificates for Consul were generated to work with `dc1` datacenter in the configuration, if you decide to change this configuration, please regenerate the certificates using this reference https://learn.hashicorp.com/tutorials/consul/deployment-guide?in=consul/production-deploy#generate-tls-certificates-for-rpc-encryption
* All docker images are based on Ubuntu 20.04 to make my life easier in case I need to connect to the container to troubleshoot anything.

1. Boot the Consul cluster with the `acl` configuration commented

`docker-compose up -d consul-server1 consul-server2 consul-server3`

The following log lines will tell you if the cluster is working as expected

```log
consul-server3    | 2021-08-29T09:28:32.807Z [INFO]  agent.server: New leader elected: payload=consul-server2
consul-server1    | 2021-08-29T09:28:32.808Z [INFO]  agent.server: New leader elected: payload=consul-server2
consul-server2    | 2021-08-29T09:28:32.751Z [INFO]  agent.server: New leader elected: payload=consul-server2
```

2. Set the env var and check if the cluster is up and running. 

```bash
$ export CONSUL_HTTP_ADDR=127.0.0.1:8500
$ consul members
Node            Address          Status  Type    Build   Protocol  DC   Segment
consul-server1  172.28.0.4:8301  alive   server  1.10.1  2         dc1  <all>
consul-server2  172.28.0.3:8301  alive   server  1.10.1  2         dc1  <all>
consul-server3  172.28.0.2:8301  alive   server  1.10.1  2         dc1  <all>
$ consul operator raft list-peers
Node            ID                                    Address          State     Voter  RaftProtocol
consul-server3  a782bd3b-7084-aea3-d4a1-4c6a9aa0dccd  172.28.0.2:8300  follower  true   3
consul-server2  3a352a43-c0e0-d4a5-11a6-df8ebd767cf7  172.28.0.3:8300  leader    true   3
consul-server1  78b3fc33-38e4-9ba6-cfab-378c6324de8b  172.28.0.4:8300  follower  true   3
```

3. Upate the cluster configuration file for each [`consul/consul-serveer{1,2,3}.hcl`](consul) adding the following configuration:

```hcl
acl {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
}
```

4. Restart the cluster 

`docker-compose restart`

5. After up and running enable the ACL 

`consul acl bootstrap` 

* Save the output information; 

* Set the HTTP token variable with the `SecretID` from the output that you saved; 

`export CONSUL_HTTP_TOKEN=111111111111111111111111` 

* Check if the cluster is up and running again; 

`consul members` or `consul info` 

6. Create a generic agent token policy ([generic-node-acl.hcl](consul/generic-node-acl.hcl))

```hcl
agent_prefix "" {
policy = "write"
}
node_prefix "" {
policy = "write"
}
service_prefix "" {
policy = "read"
}
session_prefix "" {
policy = "read"
}
```

7. Apply the policy.

You have to issue this command from inside the [consul](consul) directory

`consul acl policy create -name node-policy -description "Generic Rules for Nodes" -rules @generic-node-acl.hcl`

8. Create the generic Agent Token

`consul acl token create -description "Agent Token" -policy-name node-policy`

* Save the output of this command to use in the next step

9. Update the config in each `serverX.hcl` ([consul-server1.hcl](consul/consul-server1.hcl), [consul-server2.hcl](consul/consul-server2.hcl), [consul-server3.hcl](consul/consul-server3.hcl)) with the agent token

```hcl
acl {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
  tokens {
    agent = "4e4e9e02-78cf-05c2-4848-bd9ab6c71c2a"
  }
}
```

10. Restart the agentes

`docker-compose restart`

From now you should see a clean logs withtout any information like (`docker-compose logs -f` can help with the logs)

```log
consul-server1    | 2021-08-29T09:39:09.369Z [WARN]  agent: Coordinate update blocked by ACLs: accessorID=00000000-0000-0000-0000-000000000002
consul-server3    | 2021-08-29T09:39:11.699Z [WARN]  agent: Coordinate update blocked by ACLs: accessorID=00000000-0000-0000-0000-000000000002
consul-server2    | 2021-08-29T09:39:14.175Z [WARN]  agent: Coordinate update blocked by ACLs: accessorID=00000000-0000-0000-0000-000000000002
```

11. Access the web ui

http://localhost:8500/ui/

You're going to need the token generated on the step 5 in order to login 

## Preparing the cluster to be the Vault Storage backend.
12. Create a new Policy allowing the Vault nodes

You have to issue this command from inside the [consul](consul) directory

`consul acl policy create -name vault-policy -rules @vault-policy.hcl`

13. Create the token to allow Vault Cluster use Consul.

`consul acl token create -description "Token for Vault Service" -policy-name vault-policy`

* Save the output information

14. Create the Vault configuration file and set the Storage backend using the Token from above step

All files are fully configured already, simply replace with the current information [vault-server1.hcl](vault/vault-server1.hcl), [vault-server2.hcl](vault/vault-server2.hcl).

```hcl
storage "consul" {
    address = "consul-server1:8500"
    path = "vault"
    token = "1073a540-9651-c9e9-bd90-7fb422417cc2"
}
service_registration "consul" {
    address = "consul-server1:8500"
    token = "1073a540-9651-c9e9-bd90-7fb422417cc2"
    service = "vault"
}
```

15. Start up the vault cluster

`docker-compose up vault-server1 vault-server2`

16. Unseal the Vault cluster

* Unseal the first node from your console:

```bash
export VAULT_ADDR=http://127.0.0.1:8200/
vault operator init
```
* With the information generated set the Vault Token variable and unsel the Vault in the first node

```bash
export VAULT_TOKEN=s.NdXjjheSLj9p21cvBhSwYWQk
vault operator unseal v/6Jw14Ibpv+PTfPBQtj9goJVrHwK8VFiMJJT17pno5W
vault operator unseal m35vrzkDJfctx55Nkvux/MiPWHO+iDTJo3BSF7HuiClR
vault operator unseal taSJWglGcMcvPbf7Kgf/xSbRlABFxdo1XD8vs5/CmUTC
```
* Unseal the second node.
Since the second node is not exposed, you need to connect to the docker container and execute the same steps above
You don't need to `init` the Cluster again, only unseal 

```bash
docker exec -ti vault-server2 /bin/bash
export VAULT_ADDR=http://127.0.0.1:8200/
export VAULT_TOKEN=s.NdXjjheSLj9p21cvBhSwYWQk
vault operator unseal v/6Jw14Ibpv+PTfPBQtj9goJVrHwK8VFiMJJT17pno5W
vault operator unseal m35vrzkDJfctx55Nkvux/MiPWHO+iDTJo3BSF7HuiClR
vault operator unseal taSJWglGcMcvPbf7Kgf/xSbRlABFxdo1XD8vs5/CmUTC
exit
```
17. At this point you can see the Vault service showing up in Consul.

### Bonus

If you wish generate dynamic tokens for Consul agents using Vault and allow to use it in your automation to register agentes in your Consul cluster, you can follow the steps below

```bash
# Enable secrets backend
$ vault secrets enable consul
Success! Enabled the consul secrets engine at: consul/
# Here we need to use the internal server name to allow Vault acce the Consul cluster
$ vault write consul/config/access address=consul-server1:8500 token=${CONSUL_HTTP_TOKEN}
Success! Data written to: consul/config/access
# Create a role that maps to the Consul policy that we created in the step 6 (very generic to allow any node)
$ vault write consul/roles/consul-server-role policies=node-policy
Success! Data written to: consul/roles/consul-server-role
# Get you first Consul token using Vault
$ vault read consul/creds/consul-server-role
Key                Value
---                -----
lease_id           consul/creds/consul-server-role/OqpbCUQzz1wOSrVW7zhe70Hd
lease_duration     768h
lease_renewable    true
accessor           f6fe97eb-be27-31b9-713c-04f39f5800b9
local              false
token              b7c55825-3d61-3823-76f2-0a4a0c1d338e
# Test the Token
export CONSUL_SERVER_ACCESSOR=f6fe97eb-be27-31b9-713c-04f39f5800b9
consul acl token read -id ${CONSUL_SERVER_ACCESSOR}
AccessorID:       f6fe97eb-be27-31b9-713c-04f39f5800b9
SecretID:         b7c55825-3d61-3823-76f2-0a4a0c1d338e
Description:      Vault consul-server-role root 1630231710789796000
Local:            false
Create Time:      2021-08-29 10:08:30.7931862 +0000 UTC
Policies:
   5ec99e70-15fe-a787-ad52-5cb819854c46 - node-policy
```

To make it easier for your to use the credentials in any automation you may chose to generate the tokens and output in `json` format

```bash
$ vault read consul/creds/consul-server-role --format="json"
{
  "request_id": "f600e0ab-b8dd-911e-fcf4-ef201932cee1",
  "lease_id": "consul/creds/consul-server-role/ckiA9gXtO1eEMxpEEe89Odjn",
  "lease_duration": 2764800,
  "renewable": true,
  "data": {
    "accessor": "9b5d03e2-6507-628e-2cb6-a460cd648b2c",
    "local": false,
    "token": "df9e4b7b-2c75-8043-ab93-1413e33c5ef2"
  },
  "warnings": null
}
```

Or filter something like the token

```
$ vault read consul/creds/consul-server-role --format="json" | jq .data.token 
"df9e4b7b-2c75-8043-ab93-1413e33c5ef2"
```


## Clean-up

To stop all containers and clean up your environment, run the following commands

`docker-compose down --rmi all --remove-orphans` (it will remove all the conigurations including images and networks, be careful)

`docker system prune` (It will remove anything unused, be careful)

## References

https://learn.hashicorp.com/tutorials/vault/ha-with-consul?in=vault/day-one-consul
https://www.consul.io/docs/agent/options#configuration_files
https://learn.hashicorp.com/tutorials/consul/access-control-setup-production
https://www.consul.io/docs/security/acl/acl-rules
https://learn.hashicorp.com/tutorials/consul/access-control-setup
https://learn.hashicorp.com/tutorials/consul/vault-consul-secrets
https://learn.hashicorp.com/tutorials/consul/deployment-guide