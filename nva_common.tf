# tflint-ignore: terraform_required_providers
resource "random_password" "apikey" {
  count = var.api_key == null ? 0 : 1

  length  = 30
  special = false
}
# tflint-ignore: terraform_required_providers
resource "random_password" "haenc" {
  length  = 30
  special = false
}