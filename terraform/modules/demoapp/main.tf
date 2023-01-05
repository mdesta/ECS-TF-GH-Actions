resource "aws_ecr_repository" "mdesta_demotwo_app_ecr_repo" {
  # name = "mdesta_demotwo_app_ecr_repo" # Repo Name in AWS
  name = "mdesta_${var.environment_name}_app_ecr_repo" # Repo Name in AWS
}

##################################################

resource "aws_ecs_cluster" "mdesta_demotwo_cluster" {
  name = "mdesta-${var.environment_name}-cluster" # Cluster Name
}

###################################################

# image_tag     = data.git_repository.solibri-cloud.commit_sha

#     image              = "${var.image}:${var.image_tag}"

# image = "474034724728.dkr.ecr.eu-west-1.amazonaws.com/mdesta_${var.environment_name}_app_ecr_repo"

resource "aws_ecs_task_definition" "mdesta_demotwo_task" {
  family                   = "mdesta-${var.environment_name}-task" # Task Name
  container_definitions    = <<DEFINITION
  [
    {
      "name": "mdesta-${var.environment_name}-task",
      "image": "474034724728.dkr.ecr.eu-west-1.amazonaws.com/mdesta_${var.environment_name}_app_ecr_repo:${var.image_tag}",
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
  execution_role_arn       = aws_iam_role.mdesta_ecsTaskExecutionRole.arn
}

resource "aws_iam_role" "mdesta_ecsTaskExecutionRole" {
  name               = "mdesta_${var.environment_name}_ecsTaskExecutionRole"
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
  role       = aws_iam_role.mdesta_ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

############################################

resource "aws_ecs_service" "mdesta_demotwo_service" {
  name            = "mdesta-${var.environment_name}-service"        # Service Name, like ifc-loiservice
  cluster         = aws_ecs_cluster.mdesta_demotwo_cluster.id       # Ref to Cluster
  task_definition = aws_ecs_task_definition.mdesta_demotwo_task.arn # Blueprint for running our task
  launch_type     = "FARGATE"                                       # Compute Option
  desired_count   = 1                                               # How many containers we want

  load_balancer {
    target_group_arn = aws_lb_target_group.mdesta_target_group.arn # Ref to target group
    container_name   = aws_ecs_task_definition.mdesta_demotwo_task.family
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

resource "aws_alb" "mdesta_application_load_balancer" {
  name               = "mdesta-${var.environment_name}-lb-tf" # LB Name
  load_balancer_type = "application"
  subnets = [ # Ref to default subnets
    "${aws_default_subnet.default_subnet_a.id}",
    "${aws_default_subnet.default_subnet_b.id}"
  ]
  # Ref to security group
  # It is needed to control traffic in and out of our ALB
  security_groups = ["${aws_security_group.mdesta_load_balancer_security_group.id}"]
}

resource "aws_security_group" "mdesta_load_balancer_security_group" {
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

resource "aws_lb_target_group" "mdesta_target_group" {
  name        = "mdesta-${var.environment_name}-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.default_vpc.id
  health_check {
    matcher = "200,301,302"
    path    = "/"
  }
}

resource "aws_lb_listener" "mdesta_listener" {
  load_balancer_arn = aws_alb.mdesta_application_load_balancer.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mdesta_target_group.arn
  }
}

#################################################3

resource "aws_security_group" "service_security_group" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = ["${aws_security_group.mdesta_load_balancer_security_group.id}"]
  }

  egress {
    from_port   = 0             # any incoming port
    to_port     = 0             # any outgoing port
    protocol    = "-1"          # any outgoing protocol 
    cidr_blocks = ["0.0.0.0/0"] # traffic out to all IP addresses
  }
}
