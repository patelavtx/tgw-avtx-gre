variable "cloud" {
  description = "Cloud where this is deployed. Valid values: AWS, Azure, ALI, OCI, GCP"
  default = "AWS"  
}

variable "region" {
  description = "Specify the region of Aviatrix Transit Gateway and TGW to be deployed"
  default     = "us-east-1"
}

variable "cidr" {
  description = "What ip CIDR to use for this VPC/VNET/VCN"
  default = "10.10.10.0/23"
}

variable "account" {
  description = "The account name as known by the Aviatrix controller"  
}

variable "avx_transit_asn" {
  description = "Provide ASN number for Aviatrix Transit"
  default = 65010
}

variable "avx_transit_gw_name" {
  description = "Provide Aviatrix Transit Gateway name"
  default = "ue1transit"
}

variable "aws_tgw_asn" {
  description = "Provide ASN number for AWS TGW"
  default = 65001
}

variable "aws_tgw_name" {
  description = "Provide AWS TGW name"
  default = "ue1tgw"
}

variable "aws_tgw_cidr_block" {
    description = "Cidr block to be assigned to TGW for GRE connection"
    default = "192.168.1.0/24"
    type = string
}

variable "aws_tgw_BGP_inside_CIDR_ranges_27" {
  description = "Provide /27 IP range for four TGW BGP inside /29 CIDR"
  default = "169.254.100.0/27"
}