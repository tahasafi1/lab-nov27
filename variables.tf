#small-project prefix set 
variable "prefix" {
    type = string
    default = "small-project"
}

#Declaring subnet variable
variable "subnet" {
    type = map(object({
        cidr_block = string
        availability_zone = string
    }))
}

#Declaring security group variable
variable "security_groups" {
  description = "A map of security groups with their rules"
  type = map(object({
    description = string
    ingress_rules = optional(list(object({
      description = optional(string)
      priority    = optional(number)

      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    })))
    egress_rules = optional(list(object({
      description = optional(string)
      priority    = optional(number)
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    })))
  }))
  default = {}
}

# variable "ami" {
#     type = map(any)
#     default = {
#         us-east-1 = ""
#     }
# }

variable "ec2" {
    type = map(object({
        server_name = string
        # subnets = string
    }))
    default = {}
}




