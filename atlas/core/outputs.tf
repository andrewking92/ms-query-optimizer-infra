output "standard" {
    value = mongodbatlas_cluster.ms-query-optimizer.connection_strings[0].standard
}

output "srv" {
    value = mongodbatlas_cluster.ms-query-optimizer.connection_strings[0].standard_srv
}
