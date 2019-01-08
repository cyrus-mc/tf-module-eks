#!/bin/bash

# Assume the given role, and invoke docker with build args
#

ACCOUNT="${AWS_DEFAULT_ACCOUNT:=755621335444}"
ROLE="${AWS_DEFAULT_ROLE:=DATDevOps}"
DURATION="900"
NAME="$LOGNAME"

# call aws sts assume to generate a temporary token
KST=(`aws sts assume-role --role-arn "arn:aws:iam::$ACCOUNT:role/$ROLE" \
                          --role-session-name "$NAME" \
                          --duration-seconds $DURATION \
                          --query '[Credentials.AccessKeyId,Credentials.SecretAccessKey,Credentials.SessionToken]' \
                          --output text`)

# call docker specifying the AWS credentials as build args
docker build . --build-arg AWS_ACCESS_KEY_ID="${KST[0]}" --build-arg AWS_SECRET_ACCESS_KEY="${KST[1]}" --build-arg AWS_SESSION_TOKEN="${KST[2]}"
