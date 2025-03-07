# Create Aviatrix Transit

module "mc-transit" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "2.2.1"
  # insert the 3 required variables here
  cloud           = var.cloud
  region          = var.region
  cidr            = var.cidr
  account         = var.account
  ha_gw           = true
  gw_name         = var.avx_transit_gw_name
  local_as_number = var.avx_transit_asn
  bgp_ecmp        = true
}

# Create TGW
resource "aws_ec2_transit_gateway" "tgw" {
  description     = var.aws_tgw_name
  amazon_side_asn = var.aws_tgw_asn
  tags = {
    "Name" = var.aws_tgw_name
  }
  transit_gateway_cidr_blocks = [var.aws_tgw_cidr_block]
  vpn_ecmp_support            = "enable"
}


locals {
  avx_transit_subnet_ids            = [for x in module.mc-transit.vpc.subnets : x if length(regexall("Public-gateway-and-firewall-mgmt", x.name)) > 0][*].subnet_id
  aws_tgw_BGP_inside_CIDR_ranges_29 = cidrsubnets(var.aws_tgw_BGP_inside_CIDR_ranges_27, 2, 2, 2, 2)
}

# Create AWS TGW Attachment to Aviatrix Transit VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_to_avx_transit_vpc" {
  subnet_ids         = local.avx_transit_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = module.mc-transit.vpc.vpc_id
  tags = {
    "Name" = "${var.avx_transit_gw_name}-VPC"
  }
}

# Create AWS TGW Connect Attachment point to TGW VPC attachment
resource "aws_ec2_transit_gateway_connect" "attachment" {
  transport_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_to_avx_transit_vpc.id
  transit_gateway_id      = aws_ec2_transit_gateway.tgw.id
  tags = {
    "Name" = "${var.avx_transit_gw_name}-Connect"
  }
}

# In Aviatrix Transit Gateway VPC, create static route point TGW Cidr block to TGW

resource "aws_route" "route_to_tgw_cidr_block" {
  count = 2 # Constrain: Not able to retrieve route table ID specific for Aviatrix Transit GW LAN interface, this is a hack. Your actual number of route table may vary

  route_table_id         = module.mc-transit.vpc.route_tables[count.index]
  destination_cidr_block = var.aws_tgw_cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id

  timeouts {
    create = "5m"
  }
}

# From TGW Create GRE peering connection to Aviatrix transit via private connection.
resource "aws_ec2_transit_gateway_connect_peer" "tgw_gre_peer" {
  count                         = 4
  peer_address                  = count.index % 2 == 0 ? module.mc-transit.transit_gateway.private_ip : module.mc-transit.transit_gateway.ha_private_ip
  inside_cidr_blocks            = [local.aws_tgw_BGP_inside_CIDR_ranges_29[count.index]]
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.attachment.id
  bgp_asn                       = module.mc-transit.transit_gateway.local_as_number
  tags = {
    "Name" = "Peer-${count.index + 1}-${count.index % 2 == 0 ? module.mc-transit.transit_gateway.gw_name : module.mc-transit.transit_gateway.ha_gw_name}"
  }
}

# From Aviatrix Transit, create GRE peering connection to AWS TGW
resource "aviatrix_transit_external_device_conn" "to_tgw" {
  count              = 2
  vpc_id             = module.mc-transit.transit_gateway.vpc_id
  connection_name    = "${var.aws_tgw_name}-${count.index + 1}"
  gw_name            = module.mc-transit.transit_gateway.gw_name
  connection_type    = "bgp"
  tunnel_protocol    = "GRE"
  bgp_local_as_num   = module.mc-transit.transit_gateway.local_as_number
  bgp_remote_as_num  = aws_ec2_transit_gateway.tgw.amazon_side_asn
  remote_gateway_ip  = "${aws_ec2_transit_gateway_connect_peer.tgw_gre_peer[count.index * 2].transit_gateway_address},${aws_ec2_transit_gateway_connect_peer.tgw_gre_peer[count.index * 2 + 1].transit_gateway_address}"
  direct_connect     = true
  ha_enabled         = false
  local_tunnel_cidr  = "${cidrhost(local.aws_tgw_BGP_inside_CIDR_ranges_29[count.index * 2], 1)}/29,${cidrhost(local.aws_tgw_BGP_inside_CIDR_ranges_29[count.index * 2 + 1], 1)}/29"
  remote_tunnel_cidr = "${cidrhost(local.aws_tgw_BGP_inside_CIDR_ranges_29[count.index * 2], 2)}/29,${cidrhost(local.aws_tgw_BGP_inside_CIDR_ranges_29[count.index * 2 + 1], 2)}/29"
}
