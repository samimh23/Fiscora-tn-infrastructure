# AWS staging cost estimate

Estimate captured on 2026-07-27 from the AWS Price List API for
`eu-north-1` (`EU (Stockholm)`). USD prices are before tax and use 730 hours
for an always-on month.

## Current Terraform defaults

| Resource | Unit price | Monthly estimate |
| --- | ---: | ---: |
| EC2 `t3.medium`, Linux on-demand | $0.0432/hour | $31.54 |
| 30 GB EBS gp3 | $0.0836/GB-month | $2.51 |
| One in-use public IPv4 | $0.005/hour | $3.65 |
| **Known fixed subtotal** |  | **$37.69** |

S3 document/state storage and requests, ECR image storage, CloudFront traffic,
data transfer, CloudWatch usage, snapshots, excess T3 CPU credits and taxes are
usage-dependent and are not included in the subtotal. A practical light-usage
allowance is approximately **$38-$42/month before tax**.

AWS Budget notifications do not stop resources automatically. They can arrive
after usage has already been incurred, so the $20 budget is a warning rather
than a hard spending limit.

## Options for a $20 development budget

1. Keep `t3.medium` but start it only while testing. At 300 running hours, the
   known subtotal is about $16.97 before variable usage and tax. The EBS volume
   continues to cost about $2.51 while the instance is stopped.
2. An always-on ARM `t4g.small` has a known subtotal of about $18.71, but its
   2 GB memory is tight for the API, PostgreSQL and object storage, and it
   requires an ARM AMI plus multi-architecture container images.
3. Raise the staging budget to at least $45 for the current always-on design.

Production accounting workloads should not use the single-host staging
topology. Availability, managed database backups, monitoring, security and
legal retention will require a separate production estimate.
