# Provisioning Fully Virtualized OpenShift Clusters on OpenShift Virtualization (o3)

This project (pronounced oh-cubed) automates the deployment of fully virtualized OpenShift clusters on OpenShift Virtualization (no HCP) using Ansible and Red Hat's Advanced Cluster Management (ACM).

## Preparing Your Environment

The modules used in these roles have specific Python dependencies and collection requirements. To build an Ansible environment supporting these dependencies/requirements, find a good working directory in your workstation and clone this repository using the following command:

```shell
git clone https://github.com/nasx/o3.git
```

Next, we will create a Python Virtual Environment.

```shell
python -m venv /path/to/virtual/environment
```

Activate the virtual environment.

```shell
. /path/to/virtual/environment/bin/activate
```

Install required Python dependencies using `requirements.txt` in the root of the repository.

```shell
pip install -U -r requirements.txt
```

Finally, make sure you are in the root directory of the repository and install the required Ansible collections.

```shell
ansible-galaxy collection install -r collections/requirements.yaml
```

## Hub Service Account

The playbooks will leverage ACM to drive most of the cluster provisioning. A service account is needed on the Hub cluster to orchestrate various resources like the InfraEnv, ClusterDeployment and Agent resources and and can be created as follows:

First create a namespace, `o3` in this case but really the service account can be in any namespace.

```shell
oc new-project o3
```

Create a service account (called `o3`) in that namespace:

```shell
oc create sa -n o3 o3
```

Next, add the `cluster-admin` role to this service account:

```
oc adm policy add-cluster-role-to-user clusteradmin -n o3 -z o3 --rolebinding-name o3-cluster-admin
```

Finally, create a token for this service account.

```
oc create token -n o3 o3 --duration=8760h
```

This token should be saved in your vault using the variable `hub_token`.

## Platform Service Account

The cluster hosting the virtual machines for OpenShift is referred to as the platform cluster. Create a service account on this cluster the same way you did on the hub cluster and save the token in your vault using the variable `platform_token`.

If the clusters are the same, set the value of `platform_token` to `hub_token`.

## Ansible Vault

We will need to store tokens for the hub and platform clusters in a vault along with their respective API end points and a pull secret to access the Red Hat registries.

Create a vault with the following command:

```shell
ansible-vault create vault.yaml
```

It should contain the following:

```yaml
hub_api: https://api.hub.example.com:6443
hub_token: <o3_service_account_token_on_hub>
platform_api: https://api.platform.example.com:6443
platform_token: <o3_service_account_token_on_platform>
pull_secret: <pull_secret_json>
```

## Inventory File

Example inventory files are included in the clusters/ directory in this repository.

## Running the Automation

To kick off the installation, run the following:

```shell
ansible-playbook --ask-vault-pass -e @path/to/vault.yaml -i path/to/inventory.yaml create.yaml
```