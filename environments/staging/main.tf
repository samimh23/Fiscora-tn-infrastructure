data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

module "network" {
  source = "../../modules/network"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = var.availability_zone
}

module "registry" {
  source = "../../modules/registry"

  name_prefix = local.name_prefix
}

module "storage" {
  source = "../../modules/storage"

  name_prefix    = local.name_prefix
  aws_account_id = data.aws_caller_identity.current.account_id
}

module "compute" {
  source = "../../modules/compute"

  name_prefix          = local.name_prefix
  vpc_id               = module.network.vpc_id
  public_subnet_id     = module.network.public_subnet_id
  instance_type        = var.instance_type
  ami_ssm_parameter    = var.ami_ssm_parameter
  root_volume_size     = var.root_volume_size
  ecr_repository_arn   = module.registry.repository_arn
  documents_bucket_arn = module.storage.documents_bucket_arn
  web_bucket_arn       = module.storage.web_bucket_arn
}
