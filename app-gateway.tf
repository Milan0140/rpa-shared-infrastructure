data "azurerm_key_vault_secret" "cert" {
  name      = "${var.external_cert_name}"
  vault_uri = "${var.external_cert_vault_uri}"
}

locals {

 jui_suffix  = "${var.env != "prod" ? "-webapp" : ""}"

 webapp_internal_hostname  = "jui-webapp-${var.env}.service.core-compute-${var.env}.internal"

}

module "appGw" {
  source            = "git@github.com:hmcts/cnp-module-waf?ref=ccd/CHG0033576"
  env               = "${var.env}"
  subscription      = "${var.subscription}"
  location          = "${var.location}"
  wafName           = "${var.product}"
  resourcegroupname = "${azurerm_resource_group.rg.name}"
  common_tags       = "${var.common_tags}"

  # vNet connections
  gatewayIpConfigurations = [
    {
      name     = "internalNetwork"
      subnetId = "${data.azurerm_subnet.subnet_a.id}"
    },
  ]

  sslCertificates = [
    {
      name     = "${var.external_cert_name}"
      data     = "${data.azurerm_key_vault_secret.cert.value}"
      password = ""
    },
  ]

  # Http Listeners
  httpListeners = [
    {
      name                    = "http-listener"
      FrontendIPConfiguration = "appGatewayFrontendIP"
      FrontendPort            = "frontendPort80"
      Protocol                = "Http"
      SslCertificate          = ""
      hostName                = "${var.external_hostname}"
    },
    {
      name                    = "https-listener"
      FrontendIPConfiguration = "appGatewayFrontendIP"
      FrontendPort            = "frontendPort443"
      Protocol                = "Https"
      SslCertificate          = "${var.external_cert_name}"
      hostName                = "${var.external_hostname}"
    },
    {
      name                    = "http-www-listener"
      FrontendIPConfiguration = "appGatewayFrontendIP"
      FrontendPort            = "frontendPort80"
      Protocol                = "Http"
      SslCertificate          = ""
      hostName                = "${var.external_www_hostname}"
    },
    {
      name                    = "https-www-listener"
      FrontendIPConfiguration = "appGatewayFrontendIP"
      FrontendPort            = "frontendPort443"
      Protocol                = "Https"
      SslCertificate          = "${var.external_cert_name}"
      hostName                = "${var.external_www_hostname}"
    },
  ]
  
   # Backend address Pools
  backendAddressPools = [
    {
      name = "${var.product}-${var.env}"

      backendAddresses = [
        {
          ipAddress = "${local.webapp_internal_hostname}"
        },
      ]
    },
  ]
  use_authentication_cert = true
  backendHttpSettingsCollection = [
    {
      name                           = "backend-80"
      port                           = 80
      Protocol                       = "Http"
      CookieBasedAffinity            = "Disabled"
      AuthenticationCertificates     = ""
      probeEnabled                   = "True"
      probe                          = "http-probe"
      PickHostNameFromBackendAddress = "False"
      HostName                       = "${var.external_hostname}"
    },
      {
      name                           = "backend-443"
      port                           = 443
      Protocol                       = "Https"
      CookieBasedAffinity            = "Disabled"
      AuthenticationCertificates     = "ilbCert"
      probeEnabled                   = "True"
      probe                          = "https-probe"
      PickHostNameFromBackendAddress = "False"
      HostName                       = "${var.external_hostname}"
    },
      {
      name                           = "backend-www-80"
      port                           = 80
      Protocol                       = "Http"
      CookieBasedAffinity            = "Disabled"
      AuthenticationCertificates     = ""
      probeEnabled                   = "True"
      probe                          = "http-www-probe"
      PickHostNameFromBackendAddress = "False"
      HostName                       = "${var.external_www_hostname}"
    },
      {
      name                           = "backend-www-443"
      port                           = 443
      Protocol                       = "Https"
      CookieBasedAffinity            = "Disabled"
      AuthenticationCertificates     = "ilbCert"
      probeEnabled                   = "True"
      probe                          = "https-www-probe"
      PickHostNameFromBackendAddress = "False"
      HostName                       = "${var.external_www_hostname}"
    },
  ]

  # Request routing rules
  requestRoutingRules = [
    {
      name                = "http"
      RuleType            = "Basic"
      httpListener        = "http-listener"
      backendAddressPool  = "${var.product}-${var.env}"
      backendHttpSettings = "backend-80"
    },
    {
      name                = "https"
      RuleType            = "Basic"
      httpListener        = "https-listener"
      backendAddressPool  = "${var.product}-${var.env}"
      backendHttpSettings = "backend-443"
    },
    {
      name                = "http-www"
      RuleType            = "Basic"
      httpListener        = "http-www-listener"
      backendAddressPool  = "${var.product}-${var.env}"
      backendHttpSettings = "backend-www-80"
    },
    {
      name                = "https-www"
      RuleType            = "Basic"
      httpListener        = "https-www-listener"
      backendAddressPool  = "${var.product}-${var.env}"
      backendHttpSettings = "backend-www-443"
    },
  ]

  probes = [
    {
      name                                = "http-probe"
      protocol                            = "Http"
      path                                = "/"
      interval                            = 30
      timeout                             = 30
      unhealthyThreshold                  = 5
      pickHostNameFromBackendHttpSettings = "false"
      backendHttpSettings                 = "backend-80"
      host                                = "${var.external_hostname}"
      healthyStatusCodes                  = "200-399"                  #// MS returns 400 on /, allowing more codes in case they change it
    },
    {
      name                                = "https-probe"
      protocol                            = "Https"
      path                                = "/"
      interval                            = 30
      timeout                             = 30
      unhealthyThreshold                  = 5
      pickHostNameFromBackendHttpSettings = "false"
      backendHttpSettings                 = "backend-443"
      host                                = "${var.external_hostname}"
      healthyStatusCodes                  = "200-399"                  #// MS returns 400 on /, allowing more codes in case they change it
    },
    {
      name                                = "http-www-probe"
      protocol                            = "Http"
      path                                = "/"
      interval                            = 30
      timeout                             = 30
      unhealthyThreshold                  = 5
      pickHostNameFromBackendHttpSettings = "false"
      backendHttpSettings                 = "backend-www-80"
      host                                = "${var.external_www_hostname}"
      healthyStatusCodes                  = "200-399"                  #// MS returns 400 on /, allowing more codes in case they change it
    },
    {
      name                                = "https-www-probe"
      protocol                            = "Https"
      path                                = "/"
      interval                            = 30
      timeout                             = 30
      unhealthyThreshold                  = 5
      pickHostNameFromBackendHttpSettings = "false"
      backendHttpSettings                 = "backend-www-443"
      host                                = "${var.external_www_hostname}"
      healthyStatusCodes                  = "200-399"                  #// MS returns 400 on /, allowing more codes in case they change it
    },
  ]
}
