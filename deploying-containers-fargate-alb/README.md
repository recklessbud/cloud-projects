# Deploying Containers with fargate, Auto scaling and Loadbalancers
This is a sample project to demonstrate how to deploy containers using AWS Fargate with Auto Scaling and Load Balancers.



### Errors encounted
- Security Groups.. used nginx container image and port to test the code after that I changed to the desired container and port, forgot to change the security group ingess and egress to allow the port 