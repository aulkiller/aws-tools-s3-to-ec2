variable "s3_bucket_name" {
  description = "S3 bucket name for VHD files"
  type        = string
  default     = "your-bucket-name"
}

# IAM role for VM Import/Export
resource "aws_iam_role" "vmimport" {
  name = "vmimport"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vmie.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Inline policy with S3 + EC2 permissions
resource "aws_iam_role_policy" "vmimport" {
  name = "vmimport"
  role = aws_iam_role.vmimport.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:ModifySnapshotAttribute",
          "ec2:CopySnapshot",
          "ec2:RegisterImage",
          "ec2:Describe*"
        ]
        Resource = "*"
      }
    ]
  })
}

