

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}

##################################################################################
# DATA
##################################################################################

data "aws_ami" "aws-linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

   filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  

}

##################################################################################
# RESOURCES
##################################################################################


resource "aws_default_vpc" "default" {

}

resource "aws_security_group" "allow_ssh" {
  name        = "SSH_HTTP_ALLOW"
  description = "Allow ports 22 & 80"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "apache_terraform" {
  ami                    = data.aws_ami.aws-linux.id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  tags = {
      Name = "apache"
      Role = "web"

  }

  

  connection {
    type        = "ssh"
    user        = var.user
    host        = self.public_ip    
    private_key = file(var.private_key_path)

  }


  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y"
    ]
  }

#Creates inventory for ansible
  provisioner "local-exec" {
      command = <<EOD
cat <<EOF > inv.ini
[web] 
${aws_instance.apache_terraform.public_ip}
[web:vars]
ansible_user=${var.user}
ansible_ssh_private_key_file=${var.private_key_path}
EOF
EOD
  }

#executes ansible playbook to install apache
  provisioner "local-exec" {
    command = "ansible-playbook -i inv.ini apache.yml"
  }

}
