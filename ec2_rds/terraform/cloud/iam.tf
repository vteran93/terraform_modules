resource "aws_iam_role" "rds_s3_role" {
  name = "RDSAccessRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

resource "aws_iam_policy" "rds_s3_policy" {
  name        = "RDSPolicy"
  description = "A policy that allows EC2 to access RDS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "rds-db:connect",
          "rds:DescribeDBInstances",
        ],
        Effect   = "Allow",
        Resource = "arn:aws:rds-db:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_db_instance.db_instance.username}:${aws_db_instance.db_instance.id}/${aws_db_instance.db_instance.username}"
    },
    {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.django_static_bucket.id}",
          "arn:aws:s3:::${aws_s3_bucket.django_static_bucket.id}/*"
        ]
      }
    ]
  })
  depends_on = [ aws_db_instance.db_instance, aws_s3_bucket.django_static_bucket ]
}

resource "aws_iam_role_policy_attachment" "rds_role_policy_attachment" {
  role       = aws_iam_role.rds_s3_role.name
  policy_arn = aws_iam_policy.rds_s3_policy.arn
}


resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.rds_s3_role.name
}
