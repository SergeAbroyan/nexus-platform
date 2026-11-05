module "certificate" {
  source  = "terraform-aws-modules/acm/aws"
  version = "6.3.1"

  region = var.region

  domain_name         = var.hostname
  zone_id             = var.zone_id
  validation_method   = "DNS"
  wait_for_validation = true

  tags = merge(var.tags, { Name = var.hostname })
}

module "waf" {
  source  = "umotif-public/waf-webaclv2/aws"
  version = "5.1.2"

  name_prefix            = "${var.name}-edge"
  scope                  = "CLOUDFRONT"
  create_alb_association = false
  allow_default_action   = true

  visibility_config = {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-edge"
    sampled_requests_enabled   = true
  }

  rules = [
    {
      name            = "AWSManagedRulesCommonRuleSet"
      priority        = 10
      override_action = "none"
      managed_rule_group_statement = {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-common-rules"
        sampled_requests_enabled   = true
      }
    },
    {
      name            = "AWSManagedRulesKnownBadInputsRuleSet"
      priority        = 20
      override_action = "none"
      managed_rule_group_statement = {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-known-bad-inputs"
        sampled_requests_enabled   = true
      }
    },
    {
      name            = "AWSManagedRulesAmazonIpReputationList"
      priority        = 30
      override_action = "none"
      managed_rule_group_statement = {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-ip-reputation"
        sampled_requests_enabled   = true
      }
    },
    {
      name     = "RateLimitPerIp"
      priority = 40
      action   = "block"
      rate_based_statement = {
        aggregate_key_type = "IP"
        limit              = var.waf_rate_limit_per_five_minutes
      }
      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-rate-limit"
        sampled_requests_enabled   = true
      }
    },
  ]

  tags = var.tags
}

module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "6.7.1"

  aliases             = [var.hostname]
  comment             = "${var.name} application edge"
  enabled             = true
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  price_class         = var.price_class
  wait_for_deployment = true
  web_acl_id          = module.waf.web_acl_arn

  origin_access_control = {}

  vpc_origin = {
    for region, origin in var.origins : region => {
      arn                    = origin.load_balancer_arn
      http_port              = origin.http_port
      https_port             = 443
      name                   = "${var.name}-${region}"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = {
        items    = ["TLSv1.2"]
        quantity = 1
      }
      tags = var.tags
    }
  }

  origin = {
    for region, origin in var.origins : region => {
      domain_name = origin.domain_name
      origin_id   = region
      vpc_origin_config = {
        vpc_origin_key           = region
        origin_read_timeout      = 60
        origin_keepalive_timeout = 5
      }
    }
  }

  default_cache_behavior = {
    target_origin_id            = var.active_region
    viewer_protocol_policy      = "redirect-to-https"
    allowed_methods             = ["GET", "HEAD", "OPTIONS"]
    cached_methods              = ["GET", "HEAD", "OPTIONS"]
    compress                    = true
    cache_policy_name           = "Managed-CachingOptimized"
    origin_request_policy_name  = "Managed-AllViewer"
    response_headers_policy_key = "security"
  }

  ordered_cache_behavior = [
    {
      path_pattern                = var.api_path_pattern
      target_origin_id            = var.active_region
      viewer_protocol_policy      = "redirect-to-https"
      allowed_methods             = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods              = ["GET", "HEAD", "OPTIONS"]
      compress                    = true
      cache_policy_name           = "Managed-CachingDisabled"
      origin_request_policy_name  = "Managed-AllViewer"
      response_headers_policy_key = "security"
    },
  ]

  response_headers_policies = {
    security = {
      name    = "${var.name}-security-headers"
      comment = "Browser security headers for the ${var.name} application"
      security_headers_config = {
        content_type_options = {
          override = true
        }
        frame_options = {
          frame_option = "DENY"
          override     = true
        }
        referrer_policy = {
          referrer_policy = "strict-origin-when-cross-origin"
          override        = true
        }
        strict_transport_security = {
          access_control_max_age_sec = 31536000
          include_subdomains         = true
          override                   = true
          preload                    = true
        }
      }
    }
  }

  viewer_certificate = {
    acm_certificate_arn      = module.certificate.acm_certificate_arn
    minimum_protocol_version = "TLSv1.2_2025"
    ssl_support_method       = "sni-only"
  }

  tags = var.tags
}

locals {
  record_name = trimsuffix(var.hostname, ".${var.zone_name}")
}

module "dns_records" {
  source  = "terraform-aws-modules/route53/aws"
  version = "6.5.1"

  create_zone = false
  name        = var.zone_name

  records = {
    application_ipv4 = {
      name = local.record_name
      type = "A"
      alias = {
        name                   = module.cloudfront.cloudfront_distribution_domain_name
        zone_id                = module.cloudfront.cloudfront_distribution_hosted_zone_id
        evaluate_target_health = false
      }
    }
    application_ipv6 = {
      name = local.record_name
      type = "AAAA"
      alias = {
        name                   = module.cloudfront.cloudfront_distribution_domain_name
        zone_id                = module.cloudfront.cloudfront_distribution_hosted_zone_id
        evaluate_target_health = false
      }
    }
  }

  tags = var.tags
}
