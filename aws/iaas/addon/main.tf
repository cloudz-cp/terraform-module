data "aws_eks_cluster" "this" {
    /*depends_on = [
        module.eks
    ]*/
    name = var.eks.cluster_id
}

provider "kubernetes" {
    host            = data.aws_eks_cluster.this.endpoint//module.eks.output.cluster_endpoint//
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        args        = ["--region", var.aws_credentials.aws_region, "eks", "get-token", "--cluster-name", var.eks.cluster_id]
        command     = "aws"
        env = {
            AWS_ACCESS_KEY_ID=var.aws_credentials.aws_access_key
            AWS_SECRET_ACCESS_KEY=var.aws_credentials.aws_secret_key
            AWS_SESSION_TOKEN=var.aws_credentials.aws_session_token
            AWS_DEFAULT_REGION=var.aws_credentials.aws_region
        }
    }
}

