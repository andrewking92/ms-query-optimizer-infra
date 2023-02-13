provider "mongodbatlas" {
  public_key  = var.mongodb_atlas_api_pub_key
  private_key = var.mongodb_atlas_api_pri_key
}


data "http" "ip" {
  url = "https://ifconfig.me/ip"
}


locals {
  client_public_ip = data.http.ip.response_body
}


locals {
  username = "admin0"
  password = "admin0"
  database = "ms_test"
  collection_name = "party"
}


resource "mongodbatlas_project_ip_access_list" "ms-query-optimizer" {
      project_id = var.mongodb_atlas_project_id
      ip_address = local.client_public_ip
      comment    = "ms-query-optimizer"
}


resource "mongodbatlas_database_user" "ms-query-optimizer" {
  username           = local.username
  password           = local.password
  project_id         = var.mongodb_atlas_project_id
  auth_database_name = "admin"

  roles {
    role_name     = "atlasAdmin"
    database_name = "admin"
  }

  labels {
    key   = "Name"
    value = "ms-query-optimizer"
  }

  scopes {
    name   = "ms-query-optimizer"
    type = "CLUSTER"
  }

}


resource "mongodbatlas_cluster" "ms-query-optimizer" {
  project_id              = var.mongodb_atlas_project_id
  name                    = "ms-query-optimizer"

  provider_name           = "AWS"
  provider_region_name    = "EU_WEST_1"
  provider_instance_size_name = "M20"
  disk_size_gb                = 50

  mongo_db_major_version  = "5.0"
  auto_scaling_disk_gb_enabled = "false"

}


resource "null_resource" "ms-query-optimizer" {
  depends_on = [mongodbatlas_cluster.ms-query-optimizer]

  provisioner "local-exec" {
    command = "/bin/bash ./files/mongo.sh ${mongodbatlas_cluster.ms-query-optimizer.connection_strings[0].standard_srv} ${mongodbatlas_database_user.ms-query-optimizer.username} ${mongodbatlas_database_user.ms-query-optimizer.password} ${local.database} ${local.collection_name}"
  }
}
