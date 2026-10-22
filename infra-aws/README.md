# infra-aws: the two-tier app on AWS in CloudFormation

`two-tier.yaml` is the AWS counterpart of `../infra-gcp/`: VPC with two private subnets, RDS Postgres (no public access, encrypted, Multi-AZ in prod), a generated password in Secrets Manager, App Runner running the same API image from ECR over a VPC connector, and least-privilege roles. See Module 1b Part C in the course for the walkthrough and Lab 1b.3 for deploy, change set, drift, rollback, and delete.

```bash
aws cloudformation validate-template --template-body file://two-tier.yaml
cfn-lint two-tier.yaml
aws cloudformation deploy --stack-name two-tier-staging --template-file two-tier.yaml \
  --parameter-overrides Env=staging ImageUri=ACCOUNT.dkr.ecr.REGION.amazonaws.com/api@sha256:DIGEST \
  --capabilities CAPABILITY_IAM
```
