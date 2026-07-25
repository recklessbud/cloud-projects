variable "project_name" {
  type = string
}


variable "vpc_id"{
    type = string
}

variable "container_port" {
    type = number
}


variable "allowed_cidr_blocks" {
  type= list(string)
}