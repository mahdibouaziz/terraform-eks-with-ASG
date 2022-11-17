module "eks" {

  ##### THIS IS THE MINIMUM BASIC CONFIGURATION

  source  = "terraform-aws-modules/eks/aws"
  version = "18.30.3"

  cluster_name    = var.cluster_name
  cluster_version = "1.22.15"

  vpc_id = module.vpc.vpc_id

  #subnets (fi cours nana)
  subnet_ids = module.vpc.private_subnets



  # tags are not required - just some values for us
  tags = {
    environment = "production"
  }

  ##### CONFIGURE WHAT KIND OF WORKER NODES WE WANT TO CONNECT TO OUR CLUSTER
  # WE HAVE 3: SELF-MANAGED (EC2) - self_managed_node_groups
  #            SEMI-MANAGED (NODE GROUP) - eks_managed_node_groups
  #            MANAGED (FARGATE) - fargate_profile


  ## IN THIS DEMO WE WILL USE SELF-MANAGED: EC2
  #worker_groups fi nana
  ######### MUST BE DISCUSSED WITH MAHDI
  self_managed_node_groups = {
    default_node_group = {}
    bottlerocket = {
      name = "bottlerocket-self-mng"

      platform      = "bottlerocket"
      ami_id        = data.aws_ami.eks_default_bottlerocket.id
      instance_type = "m5.large"
      desired_size  = 2
      key_name      = aws_key_pair.this.key_name

      iam_role_additional_policies = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]

      bootstrap_extra_args = <<-EOT
      # The admin host container provides SSH access and runs with "superpowers".
      # It is disabled by default, but can be disabled explicitly.
      [settings.host-containers.admin]
      enabled = false
      # The control host container provides out-of-band access via SSM.
      # It is enabled by default, and can be disabled if you do not expect to use SSM.
      # This could leave you with no way to access the API and change settings on an existing node!
      [settings.host-containers.control]
      enabled = true
      [settings.kubernetes.node-labels]
      ingress = "allowed"
      EOT
    }

    mixed = {
      name = "mixed"

      min_size     = 1
      max_size     = 5
      desired_size = 2

      bootstrap_extra_args = "--kubelet-extra-args '--node-labels=node.kubernetes.io/lifecycle=spot'"

      use_mixed_instances_policy = true
      mixed_instances_policy = {
        instances_distribution = {
          on_demand_base_capacity                  = 0
          on_demand_percentage_above_base_capacity = 20
          spot_allocation_strategy                 = "capacity-optimized"
        }

        override = [
          {
            instance_type     = "m5.large"
            weighted_capacity = "1"
          },
          {
            instance_type     = "m6i.large"
            weighted_capacity = "2"
          },
        ]
      }
    }


    efa = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      # aws ec2 describe-instance-types --region eu-west-1 --filters Name=network-info.efa-supported,Values=true --query "InstanceTypes[*].[InstanceType]" --output text | sort
      instance_type = "c5n.9xlarge"

      post_bootstrap_user_data = <<-EOT
      # Install EFA
      curl -O https://efa-installer.amazonaws.com/aws-efa-installer-latest.tar.gz
      tar -xf aws-efa-installer-latest.tar.gz && cd aws-efa-installer
      ./efa_installer.sh -y --minimal
      fi_info -p efa -t FI_EP_RDM
      # Disable ptrace
      sysctl -w kernel.yama.ptrace_scope=0
      EOT

      network_interfaces = [
        {
          description                 = "EFA interface example"
          delete_on_termination       = true
          device_index                = 0
          associate_public_ip_address = false
          interface_type              = "efa"
        }
      ]
    }


    # Complete
    complete = {
      name            = "complete-self-mng"
      use_name_prefix = false

      subnet_ids = module.vpc.public_subnets

      min_size     = 1
      max_size     = 7
      desired_size = 1

      ami_id               = data.aws_ami.eks_default.id
      bootstrap_extra_args = "--kubelet-extra-args '--max-pods=110'"

      pre_bootstrap_user_data = <<-EOT
      export CONTAINER_RUNTIME="containerd"
      export USE_MAX_PODS=false
      EOT

      post_bootstrap_user_data = <<-EOT
      echo "you are free little kubelet!"
      EOT

      instance_type = "m6i.large"

      launch_template_name            = "self-managed-ex"
      launch_template_use_name_prefix = true
      launch_template_description     = "Self managed node group example launch template"

      ebs_optimized          = true
      vpc_security_group_ids = [aws_security_group.additional.id]
      enable_monitoring      = true

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 75
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 150
            encrypted             = true
            kms_key_id            = aws_kms_key.ebs.arn
            delete_on_termination = true
          }
        }
      }

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
        instance_metadata_tags      = "disabled"
      }

      capacity_reservation_specification = {
        capacity_reservation_target = {
          capacity_reservation_id = aws_ec2_capacity_reservation.targeted.id
        }
      }

      create_iam_role          = true
      iam_role_name            = "self-managed-node-group-complete-example"
      iam_role_use_name_prefix = false
      iam_role_description     = "Self managed node group complete example role"
      iam_role_tags = {
        Purpose = "Protector of the kubelet"
      }
      iam_role_additional_policies = [
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      ]

      create_security_group          = true
      security_group_name            = "self-managed-node-group-complete-example"
      security_group_use_name_prefix = false
      security_group_description     = "Self managed node group complete example security group"
      security_group_rules = {
        phoneOut = {
          description = "Hello CloudFlare"
          protocol    = "udp"
          from_port   = 53
          to_port     = 53
          type        = "egress"
          cidr_blocks = ["1.1.1.1/32"]
        }
        phoneHome = {
          description                   = "Hello cluster"
          protocol                      = "udp"
          from_port                     = 53
          to_port                       = 53
          type                          = "egress"
          source_cluster_security_group = true # bit of reflection lookup
        }
      }
      security_group_tags = {
        Purpose = "Protector of the kubelet"
      }

      timeouts = {
        create = "80m"
        update = "80m"
        delete = "80m"
      }

      tags = {
        ExtraTag = "Self managed node group complete example"
      }
    }



  }


  # define the K8s autentification

}
