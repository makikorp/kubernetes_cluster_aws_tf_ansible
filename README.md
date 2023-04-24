# kubernetes_cluster_aws_tf_ansible
create a k8s cluster on AWS using Terraform, Ansible, and a python script

We use Terraform to create an AWS infrastructure to host Kubernetes.  There is one master node and 3 worker nodes.

We use Ansible to provision and deploy the Kubernetes cluster.  We use a playbook for the master node, a playbook for the worker nodes, and a playbook to deploy Weave Net.

We use a python script to copy the kubernetes join command shell file to each worker node.
