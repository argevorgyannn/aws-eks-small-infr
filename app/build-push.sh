#!/usr/bin/env bash
# Build the image for the EKS nodes (linux/amd64) and push it to ECR
set -euo pipefail

REGION="${AWS_REGION:-eu-north-1}"
TAG="${1:-0.1.0}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

aws ecr get-login-password --region "${REGION}" | docker login --username AWS --password-stdin "${REGISTRY}"

# using buildx to build for amd64
docker buildx build --platform linux/amd64 -t "${REGISTRY}/demo-app:${TAG}" --push "$(dirname "$0")"
