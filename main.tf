# Define AWS provider
provider "aws" {
  region = "us-east-2"  
}

# Create a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "my-vpc"
  }
}

# Create public subnet
resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-2a"  
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet1"
  }
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2b"  
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet2"
  }
}


# Create security group for ecs
resource "aws_security_group" "ecs" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-security-group"
  }
}

#create security group for alb
resource "aws_security_group" "elb" {
  vpc_id = aws_vpc.my_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "alb-security-group"
  }
}

#create a loadbalancer
resource "aws_lb" "my_alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb.id]
  subnets            = [aws_subnet.public1.id, aws_subnet.public2.id]

  tags = {
    Name = "my-alb"
  }
}

resource "aws_lb_target_group" "my_target_group" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-299"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "my_listener" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}

resource "aws_internet_gateway" "my_internet_gateway" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my-internet-gateway"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_internet_gateway.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_route_table_association1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_route_table_association2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public_route_table.id
}


# Create the ECS cluster
resource "aws_ecs_cluster" "my_cluster" {
  name = "my-ecs-cluster"  
}

resource "aws_ecs_task_definition" "my_task_definition" {
  family                   = "angular-task"
  execution_role_arn       = aws_iam_role.my_task_execution.arn
  task_role_arn            = aws_iam_role.my_task.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = "256"   
  memory = "512"  
  
# Create an ECR repository to store the Docker image
resource "aws_ecr_repository" "my_ecr_repo" {
  name = "my-angular-repo"  
}


# Build and push the Docker image to ECR
resource "aws_ecr_lifecycle_policy" "my_ecr_lifecycle" {
  repository = aws_ecr_repository.my_ecr_repo.name

  policy = jsonencode({
    rules = [
      {
        "rulePriority"      : 10,
        "description"       : "Expire images older than 14 days",
        "selection"         : {
          "tagStatus"       : "tagged",
          "countType"       : "imageCountMoreThan",
          "countNumber"     : 10,
          "countUnit"       : "image",
          "sinceImagePushed": "14"
        },
        "action"            : {
          "type"            : "expire"
        }
      }
    ]
  })
}

resource "docker_image" "my_angular_image" {
  name          = myangularimage
  build         = "./docker/Dockerfile"  
  registry_auth = {
    address      = aws_ecr_repository.my_ecr_repo.repository_url
    username     = aws.get_caller_identity.current.arn
    password     = aws_ecr_repository.my_ecr_repo.authorization_token
  }
}


  container_definitions = <<EOF
  [
    {
      "name": "local.docker_image_name",
      "image": "docker_image.my_angular_image.latest",  
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80,
          "protocol": "tcp"
        }
      ],
      "essential": true
    }
  ]
  EOF
}

resource "aws_iam_role" "my_task_execution" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "my_task" {
  name = "ecsTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

}


# Attach the necessary policies to the task execution role
resource "aws_iam_role_policy_attachment" "task_execution_role_attachment" {
  role       = aws_iam_role.my_task.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
 
}

# Create an ECS service using Fargate launch type
resource "aws_ecs_service" "my_service" {
  name            = "my-ecs-service"  
  cluster         = aws_ecs_cluster.my_cluster.arn
  task_definition = aws_ecs_task_definition.my_task_definition.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public1.id, aws_subnet.public2.id]  
    security_groups = [aws_security_group.ecs.id]  
    assign_public_ip = true
 }


 load_balancer {
    target_group_arn = aws_lb_target_group.my_target_group.arn
    container_name   = "angular-container"
    container_port   = 80
  }
}

# Export necessary values as outputs
output "alb_dns_name" {
  value       = aws_lb.my_alb.dns_name
  description = "ALB DNS Name"
}

output "target_group_arn" {
  value       = aws_lb_target_group.my_target_group.arn
  description = "Target Group ARN"
}

output "subnet_ids" {
  value       = [aws_subnet.public1.id, aws_subnet.public2.id]
  description = "Public Subnet IDs"
}
