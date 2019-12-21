#!/bin/bash

# parse out the role we want to assume
ROLE_1=${CALLER_ARN#*/}
echo $ROLE_1
ROLE_FINAL=${ROLE_1%/*}
echo $ROLE_FINAL

# obtain credentials via STS to the correct account
read AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN < \
  <(aws sts assume-role --role-arn "arn:aws:iam::$ACCOUNT_ID:role/${ROLE_FINAL}" --role-session-name AWSCLI-session-$ACCOUNT_ID --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' | \
  jq -r 'join(" ")')

export AWS_DEFAULT_REGION=us-west-2 AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN

# https://github.com/kubernetes/kubernetes/blob/master/staging/src/k8s.io/legacy-cloud-providers/aws/aws.go
#
# TagNameSubnetInternalELB is the tag name used on a subnet to designate that
# it should be used for internal ELBs
# const TagNameSubnetInternalELB = "kubernetes.io/role/internal-elb"
#
# TagNameSubnetPublicELB is the tag name used on a subnet to designate that
# it should be used for internet ELBs
# const TagNameSubnetPublicELB = "kubernetes.io/role/elb"

for subnet in $PRIVATE_SUBNETS; do
  # check if already tagged (a key can only exist once)
  TAG_EXIST=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$subnet" --query "Tags[?Key==\`kubernetes.io/role/internal-elb\`]" --output text)
  if [[ -z $TAG_EXIST ]]; then
    echo "Tagging subnet $subnet"
    aws ec2 create-tags --resource $subnet --tags Key=kubernetes.io/role/internal-elb,Value=true
  fi
done
