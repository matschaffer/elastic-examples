data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_ami" "rhel74" {
  most_recent = true

  filter {
    name   = "name"
    values = ["RHEL-7.4_HVM_GA-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["309956199498"] # Red Hat
}

resource "aws_key_pair" "server" {
  key_name   = "${var.name}"
  public_key = "${file(var.public_key)}"
}

resource "aws_instance" "server" {
  count = "${length(var.zones)}"

  ami           = "${data.aws_ami.rhel74.id}"
  instance_type = "${var.instance_type}"
  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"

  vpc_security_group_ids = [
    "${aws_security_group.administration.id}",
    "${aws_security_group.servers.id}",
    "${aws_security_group.internal.id}",
  ]

  key_name = "${aws_key_pair.server.key_name}"

  root_block_device {
    volume_size = 100
    volume_type = "gp2"
  }

  ebs_block_device {
    device_name = "sdb"
    volume_type = "gp2"
    volume_size = 100
    delete_on_termination = true
  }

  tags {
    Name       = "${var.name}-${element(var.zones, count.index)}"
    managed-by = "terraform"
  }

  user_data = "${file(var.user_data)}"
}
