
output "transit_gateway" {
  description = "The created Aviatrix Transit Gateway as an object with all of it's attributes."
  value       = module.mc-transit
}



output "ext2conn-tgw" {
    description = "s2c"
    value = aviatrix_transit_external_device_conn.to_tgw
}


# TGW
output "tgw" {
  description = "AWS TGW"
  value = aws_ec2_transit_gateway.tgw
}