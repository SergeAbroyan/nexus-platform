locals {
  name = "${var.project_name}-${var.environment}"

  standard_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  })
}

module "waf" {
  count = var.enable_cdn && var.enable_waf ? 1 : 0

  source  = "umotif-public/waf-webaclv2/aws"
  version = "5.1.2"

  name_prefix            = "${local.name}-edge"
  scope                  = "CLOUDFRONT"
  create_alb_association = false
  allow_default_action   = true

  visibility_config = {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name}-edge"
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
        metric_name                = "${local.name}-common-rules"
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
        metric_name                = "${local.name}-known-bad-inputs"
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
        metric_name                = "${local.name}-ip-reputation"
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
        metric_name                = "${local.name}-rate-limit"
        sampled_requests_enabled   = true
      }
    },
  ]

  tags = local.standard_tags
}

module "cloudfront" {
  count = var.enable_cdn ? 1 : 0

  source  = "terraform-aws-modules/cloudfront/aws"
  version = "6.7.0"

  aliases             = [var.hostname]
  comment             = "${var.project_name} ${var.environment} application edge"
  enabled             = true
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  price_class         = var.price_class
  wait_for_deployment = true
  web_acl_id          = var.enable_waf ? module.waf[0].web_acl_arn : null

  origin_access_control = {}

  vpc_origin = {
    application = {
      arn                    = var.origin_load_balancer_arn
      http_port              = var.origin_http_port
      https_port             = var.origin_https_port
      name                   = "${local.name}-application"
      origin_protocol_policy = var.origin_protocol_policy
      origin_ssl_protocols = {
        items    = ["TLSv1.2"]
        quantity = 1
      }
      tags = local.standard_tags
    }
  }

  origin = {
    application = {
      domain_name = var.origin_domain_name
      origin_id   = "application"
      vpc_origin_config = {
        vpc_origin_key           = "application"
        origin_read_timeout      = 60
        origin_keepalive_timeout = 5
      }
    }
  }

  default_cache_behavior = {
    target_origin_id            = "application"
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
      target_origin_id            = "application"
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
      name    = "${local.name}-security-headers"
      comment = "Browser security headers for the ${local.name} application"
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
    acm_certificate_arn      = var.certificate_arn
    minimum_protocol_version = "TLSv1.2_2025"
    ssl_support_method       = "sni-only"
  }

  tags = local.standard_tags
}

module "dns_records" {
  count = var.enable_cdn ? 1 : 0

  source  = "terraform-aws-modules/route53/aws"
  version = "6.5.1"

  create_zone = false
  name        = var.zone_name

  records = {
    application_ipv4 = {
      name = var.hostname
      type = "A"
      alias = {
        name                   = module.cloudfront[0].cloudfront_distribution_domain_name
        zone_id                = module.cloudfront[0].cloudfront_distribution_hosted_zone_id
        evaluate_target_health = false
      }
    }
    application_ipv6 = {
      name = var.hostname
      type = "AAAA"
      alias = {
        name                   = module.cloudfront[0].cloudfront_distribution_domain_name
        zone_id                = module.cloudfront[0].cloudfront_distribution_hosted_zone_id
        evaluate_target_health = false
      }
    }
  }

  tags = local.standard_tags
}
