FROM dat-docker.jfrog.io/hashicorp/terraform:0.15.5

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

# Test to ensure module provides expected plan output
# Refreshing state steps are not always in the same order, obtaining just the plan only
ENTRYPOINT cd /src/test && terraform init --input=false && terraform get && \
           terraform plan -no-color | tee test.tfplan && \
           diff expected.tfplan test.tfplan && \
           echo "All tests passed!"