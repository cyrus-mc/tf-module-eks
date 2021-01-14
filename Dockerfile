FROM dat-docker.jfrog.io/hashicorp/terraform:0.13.4 AS init

# copy in provider.tf to initialize and cache required providers
WORKDIR /src/test
COPY test/provider.tf .
COPY versions.tf .

# initialize providers
RUN terraform init --input=false

# copy the rest of the source
WORKDIR /src
COPY . .

# run terraform get
WORKDIR /src/test
RUN terraform get

FROM init AS plan

# run plan (and save)
ARG AWS_ACCESS_KEY_ID=""
ARG AWS_SECRET_ACCESS_KEY=""
ARG AWS_SESSION_TOKEN=""

RUN terraform plan -no-color | tee test.tfplan

# Test to ensure module provides expected plan output
# Refreshing state steps are not always in the same order, obtaining just the plan only
RUN sed -i -n '/------------------------------------------------------------------------/,$p' test.tfplan

RUN diff expected.tfplan test.tfplan