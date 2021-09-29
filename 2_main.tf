
provider "aws" {
  region = "us-east-1"
}

variable "general_tag" {
  type        = string
  default     = "TF_redshift_MOD"
  description = "The tag that will be appended to other tags"
}

#############################################################################################################
############################################# aws_vpc #######################################################
#############################################################################################################

resource "aws_vpc" "mainvpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "${var.general_tag}-mainvpc"
  }

}

#############################################################################################################
############################################# public_subnets ################################################
#############################################################################################################

############################################# public_subnet_1 ################################################
# Frist Public subnet with name tag public_subnet_1a in us-east-1a AZ
resource "aws_subnet" "public_subnet_1" {
  cidr_block              = "10.0.2.0/24"
  vpc_id                  = aws_vpc.mainvpc.id
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.general_tag}-public_subnet_1a"
  }

  depends_on = [aws_vpc.mainvpc]
}

############################################# public_subnet_2 ################################################
# second Public subnet with name tag public_subnet_2b in us-east-1b AZ
resource "aws_subnet" "public_subnet_2" {
  cidr_block              = "10.0.4.0/24"
  vpc_id                  = aws_vpc.mainvpc.id
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.general_tag}-public_subnet_2b"
  }
  depends_on = [aws_vpc.mainvpc]
}

############################################# public_subnet_3 ################################################
# Third Public subnet with name tag public_subnet_3c in us-east-1c AZ
resource "aws_subnet" "public_subnet_3" {
  cidr_block              = "10.0.8.0/24"
  vpc_id                  = aws_vpc.mainvpc.id
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.general_tag}-public_subnet_3c"
  }
  depends_on = [aws_vpc.mainvpc]
}

#############################################################################################################
############################################# IGW_TF ########################################################
#############################################################################################################
resource "aws_internet_gateway" "IGW_TF" {
  vpc_id = aws_vpc.mainvpc.id

  tags = {
    Name = "${var.general_tag}-IGW"
  }
  depends_on = [aws_vpc.mainvpc]
}

#############################################################################################################
############################### one public aws_route_table ##################################################
#############################################################################################################

######################################### public-route-table ################################################
#  All three public subnets will share a single route table, 


resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.mainvpc.id

  # we create a route in the public_route_table to the aws_internet_gateway
  # by doing this, all our three subnets that will be associated with this rout table will be public.
  # THerefore,ec2 instances in the public subnet can reach the internet for inbound and outbound connections

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW_TF.id
  }
  tags = {
    Name = "${var.general_tag}-public_route_table"
  }

  depends_on = [aws_vpc.mainvpc, aws_internet_gateway.IGW_TF]
}

/*
On VPC creation, the AWS API always creates an initial Main Route Table. 
This resource records the ID of that Route Table under original_route_table_id. 
The "Delete" action for a main_route_table_association consists of 
resetting this original table as the Main Route Table for the VPC. 
*/

resource "aws_main_route_table_association" "main_RT_Association" {
  vpc_id         = aws_vpc.mainvpc.id
  route_table_id = aws_route_table.public_route_table.id
  depends_on     = [aws_vpc.mainvpc, aws_route_table.public_route_table]
}
#############################################################################################################
############################## Three public-route-association ###############################################
#############################################################################################################

# All three public subnets will share a single public route table, 
# so here we associate all three public subnets to the public_route_table created above

resource "aws_route_table_association" "public_subnet_1_association" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnet_1.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnet_2.id
}

resource "aws_route_table_association" "public_subnet_3_association" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnet_3.id
}


#############################################################################################################
####################################### redshift_role #######################################################
#############################################################################################################

# Let’s create a role now that we want to attach to our redshift databases:
# You create a aws_iam_role and assign the role to an redshift databases at boot time
resource "aws_iam_role" "iam_redshift_role" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "redshift.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    tag-key = "redshift-role"
    Name    = "${var.general_tag}-s3_ReadOnly"
  }


}

# Now we need to add some permissions using a policy document:
# we are using an aws managed policy here called AmazonS3ReadOnlyAccess
# by default it will allow reads only on all s3 objects by all aws resources
# json can be viewed at link below for details
# https://gist.github.com/bernadinm/6f68bfdd015b3f3e0a17b2f00c9ea3f8
resource "aws_iam_role_policy_attachment" "s3_ReadOnly_access_policy" {
  role       = aws_iam_role.iam_redshift_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}


# aws_iam_instance_profile is what we will use to attach it to our ec2 instance.
# Any instance that will use this s3_readOnly_instance_profile 
# will have the access to read all s3 objects
resource "aws_iam_instance_profile" "s3_readOnly_instance_profile" {
  name = "s3_readOnly_instance_profile"
  role = aws_iam_role.iam_redshift_role.name
}

#############################################################################################################
####################################### ec2_iam_role ########################################################
#############################################################################################################

resource "aws_iam_role" "ec2_iam_role" {

  assume_role_policy = <<EOF
{
  "Version" : "2012-10-17",
  "Statement":
  [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": ["ec2.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "ssm-full-policy-attach" {
  role       = aws_iam_role.ec2_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "EC2-IAM-Instance-Profile"
  role = aws_iam_role.ec2_iam_role.name
}
#############################################################################################################
############################## redshift_security_group ####################################################
#############################################################################################################
# terraform apply -target="aws_instance.ec2_to_test_redshift_connection"
resource "aws_instance" "ec2_to_test_redshift_connection" {

  ami                         = "ami-087c17d1fe0178315"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet_1.id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name

  user_data = <<EOF
    #!/bin/bash
    sudo amazon-linux-extras install postgresql10
  EOF
  tags = {
    Name = "${var.general_tag}-ec2_to_test_redshift_connection"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_subnet.public_subnet_1, aws_iam_instance_profile.ec2_instance_profile]
}
#############################################################################################################
############################## redshift_security_group ####################################################
#############################################################################################################

resource "aws_security_group" "redshift_security_group" {

  description = "redshift_security_group"
  vpc_id      = aws_vpc.mainvpc.id

  ingress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.ec2_to_test_redshift_connection.public_ip}/32"]
  }

  # egress: "By default, security groups allow all outbound traffic.""
  # https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html

  tags = {
    Name = "${var.general_tag}-public_SG"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_vpc.mainvpc, aws_instance.ec2_to_test_redshift_connection]
}
#############################################################################################################
############################## aws_redshift_subnet_group ####################################################
#############################################################################################################
resource "aws_redshift_subnet_group" "redshift_subnet_group" {
  name = "redshift-subnet-group"
  subnet_ids = [aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id,
  aws_subnet.public_subnet_3.id]
  tags = {
    Name = "${var.general_tag}-redshift_subnet_group"
  }

}


#############################################################################################################
############################## aws_redshift_cluster ####################################################
#############################################################################################################
resource "aws_redshift_cluster" "default" {
  cluster_identifier        = "sample-cluster"
  database_name             = "samplecluster"
  master_username           = "sampleuser"
  master_password           = "saMplepswd2021"
  node_type                 = "dc2.large"
  cluster_type              = "single-node"
  cluster_subnet_group_name = aws_redshift_subnet_group.redshift_subnet_group.id
  skip_final_snapshot       = true
  iam_roles                 = [aws_iam_role.iam_redshift_role.arn]

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_vpc.mainvpc,
    aws_security_group.redshift_security_group,
    aws_redshift_subnet_group.redshift_subnet_group,
    aws_iam_role.iam_redshift_role
  ]
}