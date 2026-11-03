output "site_url" {
  description = "URL HTTPS do site no CloudFront."
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "bucket_name" {
  description = "Nome do bucket S3 privado."
  value       = aws_s3_bucket.site.id
}

output "distribution_id" {
  description = "ID da distribuição CloudFront (usado em invalidações)."
  value       = aws_cloudfront_distribution.site.id
}

output "direct_s3_object_url" {
  description = "URL direta de um objeto S3. Deve retornar 403: o bucket é privado."
  value       = "https://${aws_s3_bucket.site.bucket_regional_domain_name}/index.html"
}

output "invalidation_command" {
  description = "Comando para limpar o cache do CloudFront após atualizar arquivos (execute manualmente)."
  value       = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.site.id} --paths \"/*\""
}
