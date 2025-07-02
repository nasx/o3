# Provisioning Fully Virtualized OpenShift Clusters on OpenShift Virtualization (o3)

This project (pronounced oh-cubed) automates the deployment of fully virtualized OpenShift clusters on OpenShift Virtualization (no HCP) using Ansible and Red Hat's Advanced Cluster Management (ACM).

## Getting Started

The automation can be executed from any Linux workstation with Kubernetes API connectivity to an ACM Hub cluster and an OpenShift Virtualization cluster. The playbooks were developed on a Fedora workstation, which is currently the only tested environment.

To begin, create a directory to organize our work. This directory will eventually include the git repository, our inventory file/vault and artifacts generated during playbook execution. We will also need to create a Python Virtual Environment and install the required Python dependencies and Ansible Collections.

```command
export WORKING_DIRECTORY=~/o3
```

```command
mkdir -p $WORKING_DIRECTORY
```

> [!NOTE]
> It doesn't really matter where this directory is created but the above will be used as an example in the rest of the documentation.

### Clone Git Repository

Clone this repository to our working directory:

```command
git clone https://github.com/nasx/o3.git $WORKING_DIRECTORY/o3
```

### Setting up a Python Virtual Environment

Using the `python` command, setup a new virtual environment as shown:

```command
python -m venv $WORKING_DIRECTORY/ansible-venv
```

Activate the virtual environment by sourcing the activation script as follows:

```command
source $WORKING_DIRECTORY/ansible-venv/bin/activate
```

After activating, the name of the virtual environment should now be visible at the beginning of your prompt.

Next, install the required Python dependencies (this will include Ansible):

```command
pip install -U -r $WORKING_DIRECTORY/o3/requirements.txt
```

Also install the required Ansible collections:

```command
ansible-galaxy collection install -r $WORKING_DIRECTORY/o3/collections/requirements.yaml
```

### Hub Cluster Service Account

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

### Virtualization Cluster Service Account

The cluster hosting the virtual machines for OpenShift is referred to as the virtualization cluster. Create a service account on this cluster the same way you did on the hub cluster and save the token in your vault using the variable `virtualization_token`.

If the clusters are the same, use the same token value for both variables.

## Ansible Vault

We will need to store tokens for the hub and virtualization clusters in a vault along with their respective API end points and a pull secret to access the Red Hat registries. The following table lists supported variables:

|Variable|Type|Required|Description|
|:---|:---|:---|:---|
|`hub_api`|String|True|Kubernetes API Endpoint for the ACM Hub Cluster in the format of `https://api.cluster.example.lab:6443`|
|`hub_token`|String|True|API Token for the o3 service account on the ACM Hub Cluster.|
|`offline_token`|String|False|Red Hat API Token for console.redhat.com. Only required if the cluster should be subscribed after provisioning.|
|`openshift_subscription`|Subscription|False|Subscription information. See the [Subscription](#subscription-custom-type) custom type for details.|
|`pull_secret`|String|True|The pull secret used to install OpenShift.|
|`virtualization_api`|String|True|Kubernetes API Endpoint for the ACM Hub Cluster in the format of `https://api.cluster.example.lab:6443`|
|`virtualization_token`|String|True|API Token for the o3 service account on the Virtualization Cluster.|

### Subscription Custom Type

|Variable|Type|Required|Description|
|:---|:---|:---|:---|
|`cluster_billing_model`|String|True|Can be one of `standard`, `marketplace`, `marketplace-aws`, `marketplace-azure`, `marketplace-rhm` or `marketplace-gcp`. In almost all cases you should use `standard`.|
|`service_level`|String|True|Can be one of `L1-L3` or `L3-Only`.|
|`subscribe`|String|True|Must be set to `true` to entitle the cluster (default is `false`).|
|`support_level`|String|True|Must be one of `Eval`, `Standard`, `Premium`, `Self-Support`, `None`, or `SupportedByIBM`.|
|`system_units`|String|True|Must be one of `Cores/vCPU` or `Sockets`.|
|`usage`|String|True|Must be one of `Production`, `Development/Test`, `Disaster Recovery` or `Academic`.|

Create a vault with the following command:

```shell
ansible-vault create $WORKING_DIRECTORY/vault.yaml
```

Make sure the vault contains the required variables from the table above:

```yaml
hub_api: https://api.hub.example.com:6443
hub_token: <o3_service_account_token_on_hub>
pull_secret: <pull_secret_json>  
openshift_subscription:  
  subscribe: false
virtualization_api: https://api.virtualization.example.com:6443
virtualization_token: <o3_service_account_token_on_virtualization>
```

## Setting up an Inventory File

A basic layout of the inventory file is shown below:

```yaml
---
all:
  children:
    pg:
      hosts:
        node1:
          <node1 vars>  
        node2:  
          <node2 vars>
        nodeN:  
          <nodeN vars>
  vars:
    <global vars>
```

The `pg` group (short for provisioning group and can be renamed to any valid group name) contains all of the nodes that will be added to our cluster. Ansible does not actually login to these nodes during the provisioning process. All other variables are stored globally in `vars`. Specific configurations for the provisioning group, as well as the global variables are detailed in the next sections.

For reference, a completed/working inventory file is available in the clusters directory at the root of this repository.

When finished, save your inventory file in `$WORKING_DIRECTORY/inventory.yaml`.

### Hostvars Reference

Each host in the inventory file can use the variables listed in the table below.

|Variable|Type|Required|Description|
|:---|:---|:---|:---|
|`annotations`|Object|False|Annotations to be appeneded to the `VirtualMachineInstance`.|
|`api_node_type`|String|True|Can be one of `master` or `worker`.|
|`autoattach_memballon`|Boolean|False|Whether to attach the Memory balloon device to the virtual machine. If `autoattach_memballon` is not defined or `false`, the `autoattachMemBalloon` setting is ommited from the `VirtualMachine` spec.|
|`autoattach_serialconsole`|Boolean|False|Whether to attach the default virtio-serial console or not. If `autoattach_serialconsole` is not defined or `false`, the `autoattachSerialConsole` setting is ommited from the `VirtualMachine` spec.|
|`block_multiqueue`|Boolean|False|Whether or not to enable virtio multi-queue for block devices. Defaults to `false`.|
|`boot_disk_name`|String|True|The name of the `DataVolume` intended to be used for RHCOS.|
|`cpu`|Object|True|This object is passed directly to `.spec.template.spec.domain.cpu` in the corresponding `VirtualMachine` resource.|
|`data_volumes`|`DataVolumes`|False|A list of `DataVolumes` to add to the virtual machine. See the [DataVolumes](#datavolumes-custom-type) custom type.|
|`dns`|List of Strings|True|A list of DNS server IP addresses.|
|`gateway`|String|True|Gateway IP for primary interface.|
|`io_threads`|Object|False|Specifies the IOThread options. Required if `io_threads_policy` is set to `supplementalPool`. This object is passed directly to `.spec.template.spec.domain.ioThreads` in the corresponding `VirtualMachine` resource.|
|`io_threads_policy`|String|False|Controls whether or not disks will share IOThreads. Can be one of `shared`, `auto` or `supplementalPool`. Defaults to `shared`.|
|`ip`|String|True|IP address of primary interface.|
|`labels`|Object|False|Labels to be appeneded to the `VirtualMachineInstance`.|
|`logical_nic_name`|String|True|The name of the NIC used in the corresponding `NMStateConfig` resource.|
|`memory`|Object|True|This object is passed directly to `.spec.template.spec.domain.memory` in the corresponding `VirtualMachine` resource.|
|`mtu`|Integer|True|MTU setting for the primary interface.|
|`network_interface_multiqueue`|Boolean|False|If specified, virtual network interfaces configured with a virtio bus will also enable the vhost multiqueue feature for network devices. Defaults to `false`.|
|`nics`|List of `Interfaces`|True|A list of `Interfaces` to add to the virtual machine. See the [Interfaces](#interfaces-custom-type) custom type.|
|`node_selector`|Object|False|This object is passed directly to `.spec.template.spec.nodeSelector` in the corresponding `VirtualMachine` resource.|
|`prefix_length`|Integer|True|The subnet mask of the hosts primary IP address in CIDR notation.|
|`resources`|Object|False|This object is passed directly to `.spec.template.spec.domain.resources` in the corresponding `VirtualMachine` resource.|

#### DataVolumes Custom Type

|Variable|Type|Required|Description|
|:---|:---|:---|:---|
|`bus`|String|True|Indicates the type of disk device to emulate. Can be one of `virtio`, `sata`, `scsi` or `usb`.|
|`dedicated_io_thread`|Boolean|False|Indicates this disk should have an exclusive IO Thread. Defaults to `false`|
|`name`|String|True|Name of the corresponding `DataVolume` custom resource.|
|`preallocation`|Boolean|False|Controls whether storage for DataVolumes should be allocated in advance. Defaults to `false`.|
|`size`|String|True|Size of the `PersistentVolumeClaim` associated with the corresponding `DataVolume` custom resource.|
|`storage_class`|String|True|The name of the `StorageClass` used to request a PVC for the corresponding `DataVolume` custom resource.|

#### Interfaces Custom Type

|Variable|Type|Required|Description|
|:---|:---|:---|:---|
|`model`|String|True|The interface model to use. Can be one of `e1000`, `e1000e`, `igb`, `ne2k_pci`, `pcnet`, `rtl8139` or `virtio`.|
|`name`|String|True|The name of the interface. The hosts primary interface must be named `default`.|
|`network_name`|String|True|The name of the `NetworkAttachmentDefinition` used to provide connectivity for this interface.|

### Inventory Variables Reference

All of the supported inventory variables are listed in the table below.

|Variable|Type|Required|Description|
|:---|:---|:---|:---|
|`acm`|ACM|True|Advanced Cluster Management specific settings. See the [ACM](#acm-custom-type) custom type.|
|`additional_trust_bundle`|String|False|A concatenated list of certificate authorities to add to the cluster.|
|`cleanup_known_hosts`|Boolean|False|Whether to remove the hosts IPs or FQDNs from the local uses `known_hosts` file.|
|`control_plane_defaults`|Object|False|This object supports all of the properties listed in [Hostvars](#hostvars-reference). If you find there are common settings for the control plane hosts, you can consolidate them here.|
|`infra_env`|InfraEnv|True|`InfraEnv` specific settings. See the [InfraEnv](#infraenv-custom-type) custom type.|
|`provision_group`|String|True|The name of the group in the inventory file containing the hosts to provision.|
|`template_debug`|Boolean|False|Whether to render templates in the `/tmp` directory for debugging purposes. Defaults to `false`.|
|`validate_certs`|Boolean|False|Whether to validate TLS certificates. Default to `false`.|
|`vm_label_selectors`|Object|True|Labels used to select all of the `VirtualMachine` resources associated with the cluster.|
|`vm_namespace`|String|True|Destination namespace for the `VirtualMachine` resources.|
|`worker_defaults`|Object|False|This object supports all of the properties listed in [Hostvars](#hostvars-reference). If you find there are common settings for the worker nodes, you can consolidate them here.|

#### ACM Custom Type

|Variable|Type|Required|Description|
|:---|:---|:---|:---|
|`base_dns_domain`|String|True|Passed to `.spec.baseDomain` in the corresponding `ClusterDeployment` custom resource.|
|`base_domain`|String|True|Base domain of the hosts (i.e. host DNS suffix).|
|`cluster_image_set`|String|True|Name of the `ClusterImageSet` to use.|
|`cluster_name`|String|True|Name of the OpenShift cluster we are deploying.|
|`managed_cluster_set`|String|True|The name of the `ManagedClusterSet` to place the corresponding `ManagedCluster` in.|
|`platform_type`|String|True|This object is passed directly to `.spec.platformType` in the corresponding `AgentClusterInstall` custom resource. Can be one of `baremetal` or `none`.|
|`user_managed_networking`|String|True|Indicates if the networking is managed by the user (e.g. external load balancing).|

#### InfraEnv Custom Type
|Variable|Type|Required|Description|
|:---|:---|:---|:---|
|`additional_ntp_servers`|List of Strings|False|A list of NTP server IPs.|
|`create`|Boolean|True|If `true`, the `InfraEnv` custom resource is created.|
|`discovery_iso_datastore`|String|True|The name of the storage class to use for the discovery ISO `DataStore`.|
|`image_type`|String|True|Can be one of `full-iso` or `minimal-iso`.|
|`labels`|Object|False|Labels to be appeneded to the `InfraEnv` resource.|
|`name`|String|True|Name of the `InfraEnv` resource.|
|`namespace`|String|True|Namespace for the `InfraEnv` resource.|
|`network_type`|String|True|Type of networking to use for the nodes. Currently only `static` is supported.|
|`nmstate_config_label_selector`|Object|True|This object is passed directly to `.spec.nmStateConfigLabelSelector` in the corresponding `InfraEnv` custom resource.|
|`pull_secret_name`|String|True|The name of the Kubernetes `Secret` containing the OpenShift pull secret.|
|`ssh_authorized_key`|String|True|The SSH public key added to core's `authorized_keys` file.|

## Running the Automation

To kick off the installation, run the following:

```shell
ansible-playbook --ask-vault-pass -e @path/to/vault.yaml -i path/to/inventory.yaml create.yaml
```

To remove the cluster after installation, run the following:

```shell
ansible-playbook --ask-vault-pass -e @path/to/vault.yaml -i path/to/inventory.yaml delete.yaml
```
> [!IMPORTANT]
> When you run the delete playbook, all of the `VirtualMachine` resources and corresponding `DataVolumes` will be deleted. This will also remove the `InfraEnv`, `ManagedCluster`, `AgentClusterInstall` and `ClusterDeployment` resources.
