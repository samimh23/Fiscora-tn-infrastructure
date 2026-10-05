# Contributing

Create a feature branch for every infrastructure change:

```powershell
git checkout -b feat/short-description
```

Before committing:

```powershell
./scripts/check.ps1
```

This single entry point checks both clouds, formatting, workflow guards, Azure
layout/migration guards and mocked runtime tests. The former cloud-specific
validation scripts were redundant and have been removed.

Use focused Conventional Commit messages:

```text
feat(network): add private database subnets
fix(storage): restrict document bucket policy
chore(terraform): update Azure provider
```

Never run `terraform apply` from an unreviewed branch. Do not use the Azure or
Google Cloud console to make routine infrastructure changes that belong in
Terraform.
