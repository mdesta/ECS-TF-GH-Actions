provider "aws" {
  region = "eu-west-1" # Region
}

resource "aws_ecr_repository" "michael_demo_app_ecr_repo" {
  name = "michael_demo_app_ecr_repo" # Repo Name in AWS
}

##################################################

resource "aws_ecs_cluster" "michael_demo_cluster" {
  name = "michael-demo-cluster" # Cluster Name
}

###################################################

resource "aws_ecs_task_definition" "michael_demo_task" {
  family                   = "michael-demo-task" # Task Name
  container_definitions    = <<DEFINITION
  [
    {
      "name": "michael-demo-task",
      "image": "${aws_ecr_repository.michael_demo_app_ecr_repo.repository_url}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "hostPort": 8080
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # Use ECS Fargate
  network_mode             = "awsvpc"    # Using awsvpc, needed for Fargate
  memory                   = 512         # Memory need for container
  cpu                      = 256         # CPU needed for container
  execution_role_arn       = aws_iam_role.Michael_ecsTaskExecutionRole.arn
}

resource "aws_iam_role" "Michael_ecsTaskExecutionRole" {
  name               = "Michael_ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.Michael_ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

############################################

resource "aws_ecs_service" "michael_demo_service" {
  name            = "michael-demo-service"                        # Service Name, like ifc-loiservice
  cluster         = aws_ecs_cluster.michael_demo_cluster.id       # Ref to Cluster
  task_definition = aws_ecs_task_definition.michael_demo_task.arn # Blueprint for running our task
  launch_type     = "FARGATE"                                     # Compute Option
  desired_count   = 2                                             # How many containers we want

  load_balancer {
    target_group_arn = aws_lb_target_group.michael_target_group.arn # Ref to target group
    container_name   = aws_ecs_task_definition.michael_demo_task.family
    container_port   = 8080 # Container port
  }

  network_configuration {
    subnets          = ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}"]
    assign_public_ip = true                                                # Providing our containers with public IPs
    security_groups  = ["${aws_security_group.service_security_group.id}"] # Allow traffic from LB SG 
  }
}

# Reference to default VPC
resource "aws_default_vpc" "default_vpc" {
}

# Reference to default subnets
resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "eu-west-1a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "eu-west-1b"
}

######################################################3

resource "aws_alb" "michael_application_load_balancer" {
  name               = "michael-demo-lb-tf" # LB Name
  load_balancer_type = "application"
  subnets = [ # Ref to default subnets
    "${aws_default_subnet.default_subnet_a.id}",
    "${aws_default_subnet.default_subnet_b.id}"
  ]
  # Ref to security group
  # It is needed to control traffic in and out of our ALB
  security_groups = ["${aws_security_group.michael_load_balancer_security_group.id}"]
}

resource "aws_security_group" "michael_load_balancer_security_group" {
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
}

resource "aws_lb_target_group" "michael_target_group" {
  name        = "michael-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.default_vpc.id
  health_check {
    matcher = "200,301,302"
    path    = "/"
  }
}

resource "aws_lb_listener" "michael_listener" {
  load_balancer_arn = aws_alb.michael_application_load_balancer.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.michael_target_group.arn
  }
}

#################################################3

resource "aws_security_group" "service_security_group" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = ["${aws_security_group.michael_load_balancer_security_group.id}"]
  }

  egress {
    from_port   = 0             # any incoming port
    to_port     = 0             # any outgoing port
    protocol    = "-1"          # any outgoing protocol 
    cidr_blocks = ["0.0.0.0/0"] # traffic out to all IP addresses
  }
}
