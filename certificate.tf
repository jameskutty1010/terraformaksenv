module "cert_manager" {
  source        = "terraform-iaac/cert-manager/kubernetes"
  cluster_issuer_email                   = "noname8434@outlook.com"
  cluster_issuer_name                    = "letsencrypt-production"
  cluster_issuer_private_key_secret_name = "letsencrypt"
}

resource "kubectl_manifest" "cluster-issuer" {
  yaml_body = (<<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: noname8434@outlook.com
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          class: nginx
          podTemplate:
            spec:
              nodeSelector:
                "kubernetes.io/os": linux
EOF
)
}
