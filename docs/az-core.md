# az-core.md : Shared Azure Infrastructure at a Tenant level

This repository contains the shared Azure infrastructure for a tenant, including opinionated practices and guidelines for implementing an Azure governance framework that aligns with best practices where practical, as well as code for automating the deployment of the infrastructure.

## Topics

- Collaboration Strategy (GIT)
  - [Git Patterns](git-patterns.md)
  - [Git Versioning](git-versioning.md)
- Subscription Strategy
- Release Strategy
- Governance
  - [Naming Conventions](wgc-naming.md)
  - [Tagging Strategy](wgc-tagging.md)
  - [Azure Policy](wgc-policy.md)
  - Azure Management Groups and Subscription Strategy
- DevOps (Github) workflows for automation
  - tf-deploy: Deploy Terraform
  - az-deploy: Deploy ARM and Bicep infrastructure definitions
- Shared Infrastructure including
  - Network Architecture
  - Key Vault Secret Management
  - Storage
  - Log Analytics Workspace
- Workload Inflation

