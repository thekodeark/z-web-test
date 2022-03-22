locals {
  module_name = "z-web-server"
  environment = "dev"
  fqdn        = "test.kodeark.com"
  hosted_zone = "kodeark.com"
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "networking" {
  source             = "app.terraform.io/KodeArkAdmin/tonara-modules/aws//modules/networking"
  version            = "> 1.0.0"
  module_name        = local.module_name
  environment        = local.environment
  cidr               = "10.10.0.0/16"
  public_subnets     = ["10.10.100.0/24", "10.10.101.0/24"]
  private_subnets    = ["10.10.0.0/24", "10.10.1.0/24"]
  availability_zones = data.aws_availability_zones.available.names
}

module "security_group_lb" {
  source  = "app.terraform.io/KodeArkAdmin/tonara-modules/aws//modules/security-group"
  version = "> 1.0.0"
  security_config = {
    vpc_id      = module.networking.vpc.id
    module_name = "${local.module_name}-lb"
    environment = local.environment
    ingress = [
      {
        from_port        = 80
        to_port          = 80
        protocol         = "tcp"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
        security_groups  = null
      },
      {
        from_port        = 443
        to_port          = 443
        protocol         = "tcp"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
        security_groups  = null
      }
    ]
    egress = [
      {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
        security_groups  = null
      }
    ]
  }
}

module "security_group_service" {
  source  = "app.terraform.io/KodeArkAdmin/tonara-modules/aws//modules/security-group"
  version = "> 1.0.0"
  security_config = {
    vpc_id      = module.networking.vpc.id
    module_name = "${local.module_name}-service"
    environment = local.environment
    ingress = [
      {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = null
        ipv6_cidr_blocks = null
        security_groups  = [module.security_group_lb.id]
      }
    ]
    egress = [
      {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
        security_groups  = null
      }
    ]
  }
}

module "ecr" {
  source      = "app.terraform.io/KodeArkAdmin/tonara-modules/aws//modules/ecr"
  version     = "> 1.0.0"
  module_name = local.module_name
  environment = local.environment
}

module "cert" {
  source      = "app.terraform.io/KodeArkAdmin/tonara-modules/aws//modules/cert"
  version     = "> 1.0.0"
  fqdn        = local.fqdn
  hosted_zone = local.hosted_zone
}

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html
module "ecs" {
  source      = "app.terraform.io/KodeArkAdmin/tonara-modules/aws//modules/ecs"
  version     = "> 1.0.0"
  module_name = local.module_name
  environment = local.environment

  public_subnets         = module.networking.public_subnets
  private_subnets        = module.networking.private_subnets
  vpc_id                 = module.networking.vpc.id
  zone_id                = module.cert.zone_id
  public_security_group  = module.security_group_lb.id
  private_security_group = module.security_group_service.id
  certificate_arn        = module.cert.arn
  fqdn                   = local.fqdn
  container_definition = {
    name      = "nginx"
    image     = module.ecr.url
    cpu       = 512
    memory    = 1024
    essential = true
    portMappings = {
      containerPort = 3000
      hostPort      = 3000
    }
    environment = [{
      name  = "PG_USER"
      value = "ASHUTOSH"
    }]
    volume = {
      name      = "service-storage"
      host_path = "/ecs/service-storage"
    }
  }
  ec2_config = {
    security_group_ids = [module.security_group_service.id]
    instance_type  = "t2.micro"
    public_key     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC8RE5kWH53AbXgEsomNl7tXAz4oLvJd4iM0M71yCpGuOo58czvnohELVSWbjQIv2SOgTQT7tnKVaVhupnKdA8Yw49PD585w1ZufWbz1mv0ntPyV9/b8b99s/Myufq2vq9DQe5sW+5TFDHuaFVKYwh9yRm1drLdSATF0g2FJdSul22D457PwYwT6nouPQRftJgMfSpklVOsTMg4oXt81KjOkn667syrjKx97H2N4PLpgwEQMFMZjsPMI4skE0Q8E3GqZaIIWiAPA8zFm0oJ/cF7WwMkBjVy135OxgRPGe1EB8In1m7RJ67vq8fhchyuviMqEJrFYmZ5tExFuNadeI0RyYRV7i4V46QjEfO5FVwodxWKLiJodsDudjuwmLcio5azIHeFB3O4Xq/EVnMcD6BsBPQSE3qpHQXlekVVXQFY2KiclRgXruKMMKmBM0uES/denWcSi100SEuIW/jEqN3zmdHxzJkvZL1qmmpARAHgPMpSLlKYOz5IYkzCi6poJY4K0AmqJgHIjKmk5+S5x0xjIt8vp+EVS9q9Uu4EDlqFrlBvHVMfEp+Ch8mIhXj8ZhSjKsICBLgoGiZt+QbEv+jOs3mAV6KDFN3gbqikpXDtt+jLAmnmGlI6F9T7wiviPjnf7y2TIvVOZL1mSqm8vDfYmUSlzzTCENGkctHJbYTY0w== ashu.singh212@gmail.com"
    root_block_device = {
      delete_on_termination = "true"
      volume_size           = "30"
      volume_type           = "gp2"
    }
  }
}
