# providers.tf
# Credenciais vêm do perfil do AWS CLI (AWS_PROFILE). Nunca escreva chaves aqui.
#
# Observação: o CloudFront é um serviço global, mas a API dele é consultada
# pelo provider configurado em us-east-1. Para este laboratório (certificado
# padrão do CloudFront, sem domínio próprio) não precisamos de outro provider.
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "terraform-na-pratica"
      Module    = "modulo-02-cloudfront"
      ManagedBy = "terraform"
    }
  }
}
