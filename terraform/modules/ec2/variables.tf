variable "vpc_id" {}
variable "public_subnets" { type = list(string) }
variable "private_subnets" { type = list(string) }
variable "environment" {}
variable "key_name" {}
variable "my_ip" {}
