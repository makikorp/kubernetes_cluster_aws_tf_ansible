data "aws_ami" "ubuntu_server" {
    most_recent = true
    owners = ["099720109477"]

    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
    }    
}

resource "random_id" "master_node_id" {
  byte_length = 2
  count       = var.master_instance_count
}

resource "random_id" "worker_node_id" {
  byte_length = 2
  count       = var.worker_instance_count
}

resource "aws_key_pair" "kube_auth" {
  key_name = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_instance" "master_node" {
  count         = var.master_instance_count
  instance_type = var.master_instance_type
  ami           = data.aws_ami.ubuntu_server.id
  key_name = aws_key_pair.kube_auth.id
  vpc_security_group_ids = [aws_security_group.kube_security_group.id]
  subnet_id              = aws_subnet.kube_public_subnet[count.index].id
  root_block_device {
    volume_size = var.main_vol_size
  }
    tags = {
    Name = "master_node-${random_id.master_node_id[count.index].dec}"
  }

  #adds EC2 instance IP address to kube_master file -- the "aws ec2 wait" command waits for the instance to be running
  provisioner "local-exec" {
    command = "printf '\n${self.public_ip}' >> kube_master && printf '${self.public_ip}' >> kube_master_ip && aws ec2 wait instance-status-ok --instance-ids ${self.id} --region us-west-2"
  }
}



#Call and run Kubernetes Master playbook
resource "null_resource" "kube_master_install" {
  depends_on = [aws_instance.master_node]
  provisioner "local-exec" {
    command = "ansible-playbook -i kube_master --key-file /Users/ericmaki/.ssh/awsTerraTest playbooks/Install_kube_master.yml"
  }

}


resource "aws_instance" "worker_node" {
  count         = var.worker_instance_count
  instance_type = var.worker_instance_type
  ami           = data.aws_ami.ubuntu_server.id
  key_name = aws_key_pair.kube_auth.id
  vpc_security_group_ids = [aws_security_group.kube_security_group.id]
  subnet_id              = aws_subnet.kube_public_subnet[count.index].id
  root_block_device {
    volume_size = var.main_vol_size
  }
    tags = {
    Name = "worker_node-${random_id.worker_node_id[count.index].dec}"
  }

  #adds EC2 instance IP address to kube nodes file -- the "aws ec2 wait" command waits for the instance to be running
  provisioner "local-exec" {
    command = "printf '\n${self.public_ip}' >> kube_nodes && aws ec2 wait instance-status-ok --instance-ids ${self.id} --region us-west-2"
  }
}


#Call and run kubernetes playbook for worker nodes
resource "null_resource" "kube_worker_install" {
  depends_on = [aws_instance.worker_node]
  provisioner "local-exec" {
    command = "ansible-playbook -i kube_nodes --key-file /Users/ericmaki/.ssh/awsTerraTest playbooks/Install_kube_worker.yml"
  }

}

resource "time_sleep" "wait_for_master_install" {
  create_duration = "60s"

  depends_on = [null_resource.kube_master_install]
}


#Call and run playbook to deploy Weave on kubernetes
resource "null_resource" "kube_weave_install" {
  depends_on = [time_sleep.wait_for_master_install]
  provisioner "local-exec" {
    command = "ansible-playbook -i kube_master --key-file /Users/ericmaki/.ssh/awsTerraTest playbooks/kubernetes_weave.yml"
  
  
  }
}


output "master_access" {
  value = {for i in aws_instance.master_node[*] : i.tags.Name => "${i.public_ip}"}
}

output "worker_access" {
  value = {for i in aws_instance.worker_node[*] : i.tags.Name => "${i.public_ip}"}
}