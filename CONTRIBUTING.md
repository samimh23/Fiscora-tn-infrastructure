# Contributing

Create a feature branch for every infrastructure change:

```powershell
git checkout -b feat/short-description
```

Before committing:

```powershell
.\scripts\validate.ps1
```

Use focused Conventional Commit messages:

```text
feat(network): add private database subnets
fix(storage): restrict document bucket policy
chore(terraform): update AWS provider
```

Never run `terraform apply` from an unreviewed branch. Do not use the AWS
console to make routine infrastructure changes that belong in Terraform.

