variable "aws_region" {
  description = "The AWS Region where we will build our infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "The name of our secure EKS (Kubernetes) cluster"
  type        = string
  default     = "weather-app-cluster"
}

variable "vpc_cidr" {
  description = "The IP address block for our virtual private network"
  type        = string
  default     = "10.0.0.0/16"
}