# 6.4.0 (2022-04-21)
## Enhancement

- Output `identity_provider_url` for IAM `trust_relationship`s to refer

# 6.3.0 (2022-04-12)
## Enhancement

- Automatically populate requisite EKS OIDC provider thumbprint retroactively to resolve `InvalidIdentityToken` errors being logged when thrown by the aws sdk for apps migrated off of kiam