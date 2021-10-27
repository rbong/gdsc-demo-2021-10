terraform {
  backend "gcs" {}
}

provider "google" {
  project     = var.project
  region      = "us-east1"
  credentials = "./service-key.json"
}

provider "google-beta" {
  project     = var.project
  region      = "us-east1"
  credentials = "./service-key.json"
}

variable project {}

variable zone_name {}

variable domain_name {}

### Shared Resources ###

data "google_dns_managed_zone" "main" {
  name = var.zone_name
}

### Backend resources ###

locals {
  # Extract custom function configuration from Swagger metadata
  cloudfunction_configs = {
    for config in flatten([
      for path_key, path in jsondecode(file("./api/service.json")).paths : [
        for method_key, method in path : method.x-gdsc-function
        if contains(keys(method), "x-gdsc-function")
      ]
    ]) :
    config.name => config
  }
}

data "google_iam_policy" "run_invoker" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_endpoints_service" "api" {
  service_name = "api.${var.domain_name}"

  openapi_config = templatefile("api/service.json", {
    host               = "api.${var.domain_name}"
    cloudfunction_host = "https://us-east1-${var.project}.cloudfunctions.net"
  })
}


resource "google_project_service" "api" {
  service = google_endpoints_service.api.service_name
}

resource "google_cloud_run_service" "api" {
  name     = "api"
  location = "us-east1"

  template {
    spec {
      containers {
        image = "gcr.io/endpoints-release/endpoints-runtime-serverless:2"

        env {
          # NOTE: Google recommends building the config into your service, not using ENDPOINTS_SERVICE_NAME
          name  = "ENDPOINTS_SERVICE_NAME"
          value = "api.${var.domain_name}"
        }

        env {
          name  = "ESPv2_ARGS"
          value = "--cors_preset=basic"
        }
      }
    }
  }

  depends_on = [
    google_endpoints_service.api
  ]
}

resource "google_cloud_run_service_iam_policy" "api_run" {
  location    = google_cloud_run_service.api.location
  project     = google_cloud_run_service.api.project
  service     = google_cloud_run_service.api.name
  policy_data = data.google_iam_policy.run_invoker.policy_data
}

resource "google_cloud_run_domain_mapping" "api" {
  location = google_cloud_run_service.api.location
  name     = "api.${var.domain_name}"

  metadata {
    namespace = var.project
  }

  spec {
    route_name       = google_cloud_run_service.api.name
    certificate_mode = "AUTOMATIC"
  }
}

resource "google_dns_record_set" "cloud_run_recordset" {
  for_each     = { for o in google_cloud_run_domain_mapping.api.status[0].resource_records : o.name => o }

  managed_zone = var.zone_name
  name         = "${each.value.name}.${var.domain_name}."
  type         = each.value.type
  rrdatas      = [each.value.rrdata]
  ttl          = 300
}

resource "google_storage_bucket" "api_builds" {
  name     = "gdsc-api-builds"
  location = "us-east1"

  versioning {
    enabled = true
  }
}

data "archive_file" "api_build" {
  type        = "zip"
  output_path = "./build/api.zip"

  dynamic "source" {
    for_each = concat(["package.json", "yarn.lock"], tolist(fileset("./api", "src/**/*")))

    content {
      content  = file("./api/${source.value}")
      filename = source.value
    }
  }
}

resource "google_storage_bucket_object" "api_build" {
  name = "api_${data.archive_file.api_build.output_md5}.zip"

  bucket = google_storage_bucket.api_builds.name
  source = data.archive_file.api_build.output_path
}

resource "google_cloudfunctions_function" "api" {
  for_each = local.cloudfunction_configs

  name        = each.value.name
  entry_point = each.value.name
  runtime     = "nodejs16"

  source_archive_bucket = google_storage_bucket.api_builds.name
  source_archive_object = google_storage_bucket_object.api_build.name

  timeout      = 540
  trigger_http = true
}

resource "google_project_iam_member" "api_functions_token_create" {
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${var.project}@appspot.gserviceaccount.com"
}

### Frontend resources ###

# Build resources

resource "google_storage_bucket" "static" {
  name     = "gdsc-static"
  location = "us-east1"

  uniform_bucket_level_access = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html"
  }

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket_iam_member" "static" {
  bucket = google_storage_bucket.static.name
  role   = "roles/storage.legacyObjectReader"
  member = "allUsers"
}

resource "google_storage_bucket_object" "static" {
  for_each = fileset("./app/build/", "**")

  name = each.value

  bucket = google_storage_bucket.static.name
  source = "./app/build/${each.value}"

  # Ensure CSS files have proper content type
  content_type = length(regexall("\\.css$", each.value)) == 1 ? "text/css; charset=utf-8" : ""
}

# DNS resources

resource "google_compute_global_address" "public" {
  name = "gdsc-public"

  ip_version   = "IPV4"
  address_type = "EXTERNAL"
}

resource "google_dns_record_set" "public" {
  name = "${var.domain_name}."

  managed_zone = var.zone_name
  type         = "A"
  ttl          = 3600
  rrdatas      = [google_compute_global_address.public.address]
}

# URL map resources

resource "google_compute_backend_bucket" "static" {
  name = "gdsc-static"

  bucket_name = google_storage_bucket.static.name
  enable_cdn  = true
}

resource "google_compute_url_map" "default" {
  name = "gdsc-url-map"

  default_service = google_compute_backend_bucket.static.self_link

  host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name = "allpaths"

    default_service = google_compute_backend_bucket.static.self_link

    # Rewrite plain routes to use their corresponding html files
    dynamic "path_rule" {
      for_each = [
        for path in fileset("./app/build/", "**/*.html") : {
          path     = path
          basename = replace(path, ".html", "")
        }
        if path != "index.html" && path != "200.html"
      ]

      content {
        paths = ["/${path_rule.value.basename}", "/${path_rule.value.basename}/"]

        service = google_compute_backend_bucket.static.self_link

        route_action {
          url_rewrite {
            path_prefix_rewrite = path_rule.value.path
          }
        }
      }
    }
  }
}

# HTTPS resources

resource "google_compute_managed_ssl_certificate" "public" {
  provider = google-beta
  name     = "gdsc-ssl-certificate"

  managed {
    domains = [var.domain_name]
  }
}

resource "google_compute_target_https_proxy" "https_proxy" {
  name = "gdsc-https-proxy"

  url_map          = google_compute_url_map.default.self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.public.self_link]
}

resource "google_compute_global_forwarding_rule" "https" {
  name = "gdsc-https-rule"

  target     = google_compute_target_https_proxy.https_proxy.self_link
  ip_address = google_compute_global_address.public.address
  port_range = "443"
}

# HTTP resources

resource "google_compute_url_map" "http_redirect" {
  name = "gdsc-http-redirect"

  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

resource "google_compute_target_http_proxy" "http_redirect" {
  name = "gdsc-http-redirect"

  url_map = google_compute_url_map.http_redirect.self_link
}

resource "google_compute_global_forwarding_rule" "http_redirect" {
  name = "gdsc-http-rule"

  target     = google_compute_target_http_proxy.http_redirect.self_link
  ip_address = google_compute_global_address.public.address
  port_range = "80"
}
