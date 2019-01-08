FROM datinc/terraform:0.11.7-1 AS init

# copy in provider.tf to initialize and cache required providers
WORKDIR /src/test
COPY test/provider.tf .

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

RUN terraform plan
