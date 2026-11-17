# creates the ALB for ingress
# It needs AWS permissions, given through EKS Pod Identity like in secrets.tf

#  policies from https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/<controller-version>/docs/install/iam_policy.json
resource "aws_iam_policy" "lb_controller" {
  name   = "${var.cluster_name}-lb-controller"
  policy = file("${path.module}/lb-controller-iam-policy.json")
}

resource "aws_iam_role" "lb_controller" {
  name               = "${var.cluster_name}-lb-controller"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

resource "aws_eks_pod_identity_association" "lb_controller" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lb_controller.arn
}
