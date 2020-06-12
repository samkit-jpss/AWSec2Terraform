provider "aws" {
  region = "ap-south-1"
  profile = "samkit"
}
resource "aws_security_group" "tsg" {
  name        = "myfirewall"
  description = "Allow inbound traffic"
  vpc_id = "vpc-41f0ed29"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
resource "aws_instance" "os1" {
	ami = "ami-0447a12f28fddb066"
	instance_type = "t2.micro"
	key_name = "key1"
	security_groups = ["myfirewall"]
tags = {
	Name = "OsFromTerraform"
	}
   }
output "OsId" {
  value = aws_instance.os1.id
}
resource "aws_ebs_volume"  "ebsvol"{
	availability_zone = aws_instance.os1.availability_zone
	size = 1
 
	tags = {
	  Name = "myos1ebs"
               }
  }
resource "aws_volume_attachment" "ebsat"{
	device_name = "/dev/sdd"
	volume_id = aws_ebs_volume.ebsvol.id 
	instance_id = aws_instance.os1.id

}
resource "aws_ebs_snapshot" "snapshot" {
  volume_id = aws_ebs_volume.ebsvol.id

  tags = {
    Name = "FromTerraSnap"
  }
}
output "ebsId" {
  value = aws_ebs_volume.ebsvol.id
 }

resource "aws_s3_bucket" "b" {
  bucket = "samkit-t-bucket"
  acl    = "private"

  tags = {
    Name        = "My bucket"
   }
}
output "s3out"{
  value = aws_s3_bucket.b
}

locals {
  s3_origin_id = "myS3Origin"
}
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Some comment"
}
output "origin_access_identity" {
  value = aws_cloudfront_origin_access_identity.origin_access_identity
}
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.b.arn}/*"]
principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }
statement {
    actions   = ["s3:ListBucket"]
    resources = ["${aws_s3_bucket.b.arn}"]
principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }
}
resource "aws_s3_bucket_policy" "example" {
  bucket = aws_s3_bucket.b.id
  policy = data.aws_iam_policy_document.s3_policy.json
}


resource "aws_cloudfront_distribution" "s3_distri" {
  origin {
    domain_name = aws_s3_bucket.b.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
   s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }
  enabled             = true
  is_ipv6_enabled     = true
default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
 restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
viewer_certificate {
    cloudfront_default_certificate = true
  }
}
resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebsat,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/91811/Downloads/key1.pem")
    host     = aws_instance.os1.public_ip
  }
 provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdd",
      "sudo mount  /dev/xvdd  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/samkit-jpss/MultiCloud.git /var/www/html/"
    ]
  }
}
output "myos_ip" {
  value = aws_instance.os1.public_ip
}  
