# -----------------------------------------------------------------------------
# main.tf - Módulo 02: S3 privado + CloudFront (OAC)
#
# Neste módulo vários recursos se conectam. O Terraform descobre a ORDEM
# analisando as referências entre eles (grafo de dependências):
#
#   aws_s3_bucket.site ----------------------+
#        |                                    |
#        v                                    v
#   aws_cloudfront_distribution.site <-- aws_cloudfront_origin_access_control.site
#        |
#        v
#   aws_s3_bucket_policy.site   (precisa do ARN da distribuição)
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# Política de cache gerenciada pela AWS. Usamos um data source para buscar o
# ID pelo NOME, evitando escrever IDs fixos no código.
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

locals {
  bucket_name      = "tfpratica-m02-${data.aws_caller_identity.current.account_id}-us-east-1"
  application_path = "${path.module}/../application"

  # Mapa extensão -> Content-Type, usado ao enviar arquivos.
  content_types = {
    ".html" = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
  }

  # fileset lista os arquivos da pasta application (retorna um conjunto de nomes).
  site_files = fileset(local.application_path, "**")
}

# 1) BUCKET PRIVADO ------------------------------------------------------------
resource "aws_s3_bucket" "site" {
  bucket        = local.bucket_name
  force_destroy = true # facilita o destroy do laboratório

  tags = {
    Name = "Modulo 02 - Site privado"
  }
}

# Bloqueia TODO acesso público. Somente o CloudFront (via policy) lerá os objetos.
resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# 2) ORIGIN ACCESS CONTROL (OAC) ----------------------------------------------
# O OAC faz o CloudFront ASSINAR as requisições enviadas ao S3 (SigV4).
# Assim o S3 sabe que a chamada veio do CloudFront.
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "tfpratica-m02-oac"
  description                       = "OAC do laboratorio do modulo 02"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 3) DISTRIBUIÇÃO CLOUDFRONT --------------------------------------------------
resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  comment             = "Terraform na Pratica - Modulo 02"
  default_root_object = "index.html"     # URL raiz (/) entrega index.html
  price_class         = "PriceClass_100" # menor custo: América do Norte e Europa
  is_ipv6_enabled     = true

  origin {
    origin_id = "s3-site"

    # IMPORTANTE: usamos o endpoint REGIONAL (REST) do bucket, não o endpoint
    # de website. O OAC NÃO funciona com o endpoint de website do S3.
    domain_name = aws_s3_bucket.site.bucket_regional_domain_name

    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-site"
    viewer_protocol_policy = "redirect-to-https" # HTTP vira HTTPS
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Certificado padrão *.cloudfront.net (sem domínio próprio, sem Route 53).
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "Modulo 02 - CloudFront"
  }
}

# 4) POLÍTICA DO BUCKET: só ESTA distribuição pode ler -------------------------
resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PermitirLeituraSomenteDoCloudFront"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.site.arn}/*"
        Condition = {
          StringEquals = {
            # ARN da distribuição: atributo computado, só existe após a criação.
            "AWS:SourceArn" = aws_cloudfront_distribution.site.arn
          }
        }
      }
    ]
  })

  # A AWS pode rejeitar alterações simultâneas no mesmo bucket
  # (OperationAborted). Forçamos a ordem: primeiro o bloqueio de acesso
  # público, depois a política. O Terraform não infere isso sozinho, pois
  # os dois recursos não se referenciam.
  depends_on = [aws_s3_bucket_public_access_block.site]
}

# 5) ARQUIVOS DO SITE ---------------------------------------------------------
# for_each cria UMA instância do recurso para cada arquivo encontrado.
# Endereços: aws_s3_object.files["index.html"], aws_s3_object.files["style.css"]...
resource "aws_s3_object" "files" {
  for_each = local.site_files

  bucket = aws_s3_bucket.site.id
  key    = each.value
  source = "${local.application_path}/${each.value}"
  etag   = filemd5("${local.application_path}/${each.value}")

  # regex extrai a extensão (ex.: ".css"); lookup busca o tipo no mapa.
  content_type = lookup(
    local.content_types,
    try(regex("\\.[^.]+$", each.value), ""),
    "application/octet-stream"
  )
}
