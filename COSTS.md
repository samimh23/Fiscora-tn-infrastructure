# AWS staging cost estimate

> This file describes only the legacy AWS staging stack. The Azure application
> and Google Cloud Qwen extraction service have separate cost controls. The Google
> Cloud service defaults to zero minimum instances, one maximum L4 instance,
> and an alert budget; see [`gcp/README.md`](gcp/README.md). Budget alerts do not
> stop spending automatically.

Estimate updated on 2026-08-01 from the AWS Price List API for
`eu-north-1` (`EU (Stockholm)`). USD prices are before tax and use 730 hours
for an always-on month.

## Deployed staging defaults

| Resource | Unit price | Monthly estimate |
| --- | ---: | ---: |
| EC2 `t4g.small`, Linux on-demand | $0.0172/hour | $12.56 |
| 20 GB EBS gp3 | $0.0836/GB-month | $1.67 |
| One in-use public IPv4 | $0.005/hour | $3.65 |
| **Known fixed subtotal** |  | **$17.88** |

S3 document/state storage and requests, ECR image storage, CloudFront traffic,
data transfer, CloudWatch usage, snapshots, excess T3 CPU credits and taxes are
usage-dependent and are not included in the subtotal. A practical light-usage
allowance is approximately **$18-$20/month before tax** for light staging use.

AWS Budget notifications do not stop resources automatically. They can arrive
after usage has already been incurred, so the $20 budget is a warning rather
than a hard spending limit.

## Operating within the $20 development budget

The ARM `t4g.small` keeps the known fixed subtotal below $20, but its 2 GB of
memory is tight for the API, PostgreSQL and object storage. The host therefore
uses a 1 GB swap file and explicit container memory limits. Malware scanning
is disabled in staging. Stop the EC2 instance when it is not needed to reduce
compute charges; EBS and public IPv4 allocation charges may continue.

The account also contains an unrelated stopped `g6.xlarge`. It is outside this
Terraform project and may still incur EBS storage charges even while stopped.

Production accounting workloads should not use the single-host staging
topology. Availability, managed database backups, monitoring, security and
legal retention will require a separate production estimate.
