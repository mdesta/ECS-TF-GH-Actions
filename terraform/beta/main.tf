module "demo_app" {
  source           = "../modules/demoapp"
  environment_name = local.environment_name
  image_tag        = var.image_tag 
}