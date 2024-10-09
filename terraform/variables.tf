variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "db_name" {
  default = "golang"
}

variable "db_username" {
  default = "postgres"
}

variable "db_password" {
  default = "new_pass"
}

variable "key_name" {
  description = "Name of the EC2 key pair"
  default     = "golang-pair"
}