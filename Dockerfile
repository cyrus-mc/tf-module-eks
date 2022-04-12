FROM dat-docker.jfrog.io/hashicorp/terraform:1.0.8

RUN apk add python3 && \
    python3 -m ensurepip

# copy in provider.tf to initialize and cache required providers
WORKDIR /src/test
COPY test/provider.tf .
COPY versions.tf .

# copy the rest of the source
WORKDIR /src
COPY . .

# run plan (and save)
ENV AWS_ACCESS_KEY_ID=""
ENV AWS_SECRET_ACCESS_KEY=""
ENV AWS_SESSION_TOKEN=""

WORKDIR /src/test

# Test to ensure module provides expected plan output
# Refreshing state steps are not always in the same order, obtaining just the plan only
ENTRYPOINT terraform init --input=false && \
           python3 eks.py && \
           echo "All tests passed!"