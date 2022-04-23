#!/bin/bash -e

IMAGE_NAME=$(basename "$(pwd)")-test-run
docker build . -t "$IMAGE_NAME"

# call docker specifying the AWS credentials as build args
docker run --mount type=bind,source="$(pwd)/test",target=/src/test \
           --mount type=bind,source="$HOME/.aws",target=/root/.aws \
           --rm \
           --name "$IMAGE_NAME" \
           "$IMAGE_NAME"
