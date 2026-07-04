resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# --- WAF policy: OWASP Core Rule Set + custom rules -----------------------
resource "azurerm_web_application_firewall_policy" "this" {
  name                = "waf-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"   # block, not just log
    request_body_check          = true
    file_upload_limit_in_mb     = 10
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"     # covers SQLi, XSS, RCE, protocol anomalies (OWASP API/Web Top 10)
    }

    # Reduce false positives on legitimate JSON fraud-feature payloads
    # without disabling the underlying protections.
    exclusion {
      match_variable          = "RequestArgNames"
      selector                = "TransactionAmt"
      selector_match_operator = "Equals"
    }
  }

  # --- Custom rule 1: rate-based brute-force / abuse protection ----------
  custom_rules {
    name      = "RateLimitAuthEndpoint"
    priority  = 1
    rule_type = "RateLimitRule"
    action    = "Block"

    rate_limit_duration    = "OneMin"
    rate_limit_threshold   = 60
    group_rate_limit_by    = "ClientAddr"

    match_conditions {
      match_variables {
        variable_name = "RequestUri"
      }
      operator           = "Contains"
      match_values        = ["/api/v1/auth/token"]
      negation_condition = false
    }
  }

  # --- Custom rule 2: block requests with no/invalid content-type on
  #     write endpoints (defence-in-depth alongside app-level validation)
  custom_rules {
    name      = "BlockNonJsonInference"
    priority  = 2
    rule_type = "MatchRule"
    action    = "Block"

    match_conditions {
      match_variables {
        variable_name = "RequestUri"
      }
      operator           = "Contains"
      match_values        = ["/api/v1/inference/predict"]
      negation_condition = false
    }

    match_conditions {
      match_variables {
        variable_name = "RequestHeaders"
        selector      = "Content-Type"
      }
      operator           = "Contains"
      match_values        = ["application/json"]
      negation_condition = true   # block when Content-Type is NOT json
    }
  }

  # --- Custom rule 3: geo-fencing (tune to actual expected client base) --
  custom_rules {
    name      = "BlockDisallowedGeos"
    priority  = 3
    rule_type = "MatchRule"
    action    = "Block"
    enabled   = var.enable_geo_block

    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }
      operator           = "GeoMatch"
      match_values        = var.blocked_country_codes
      negation_condition = false
    }
  }
}

# --- Application Gateway (WAF_v2 SKU) -------------------------------------
resource "azurerm_application_gateway" "this" {
  name                = "appgw-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
  firewall_policy_id  = azurerm_web_application_firewall_policy.this.id

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  autoscale_configuration {
    min_capacity = 2
    max_capacity = 6
  }

  gateway_ip_configuration {
    name      = "gw-ip-config"
    subnet_id = var.appgw_subnet_id
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  frontend_port {
    name = "port-443"
    port = 443
  }

  # TLS 1.3 / 1.2-only policy — legacy protocols and weak ciphers disabled
  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101S"  # TLS1.2 min, modern cipher suites; use custom policy for TLS1.3-only once GA in target region
  }

  ssl_certificate {
    name                = "appgw-tls-cert"
    key_vault_secret_id = var.tls_certificate_keyvault_secret_id
  }

  backend_address_pool {
    name  = "aks-inference-backend"
  }

  backend_http_settings {
    name                                = "https-backend-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                    = 30
    pick_host_name_from_backend_address = true
  }

  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "port-443"
    protocol                       = "Https"
    ssl_certificate_name           = "appgw-tls-cert"
  }

  request_routing_rule {
    name                       = "route-to-aks"
    rule_type                  = "Basic"
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "aks-inference-backend"
    backend_http_settings_name = "https-backend-settings"
    priority                   = 100
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.appgw_identity_id]
  }
}
