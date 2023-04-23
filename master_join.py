import sys
import os
import fileinput
import subprocess
#from scp import SCPClient
#from paramiko import SSHClient

with open('kube_master_ip', 'r') as file:
    masterip = file.read()

print(masterip)

masterjoin = subprocess.Popen(["scp", "-i", "/home/ubuntu/.ssh/awsTerraTest", "-o", "StrictHostKeyChecking=no", f"ubuntu@{masterip}:/home/ubuntu/kubeadm_join_command.sh", "/home/ubuntu"])
sts = os.waitpid(masterjoin.pid, 0)
