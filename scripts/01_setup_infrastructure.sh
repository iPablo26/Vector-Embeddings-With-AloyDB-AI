#!/usr/bin/env bash
# ==============================================================================
# Script: 01_setup_infrastructure.sh
# Description: Provisions GCP network peering, AlloyDB cluster, instance,
#              IAM permissions, and GCE client VM.
# ==============================================================================
set -euo pipefail

# Configuration
export PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"
export REGION="${REGION:-us-central1}"
export ZONE="${ZONE:-us-central1-a}"
export ADBCLUSTER="${ADBCLUSTER:-alloydb-aip-01}"
export GCEVM="${GCEVM:-instance-1}"

echo "==> Configuring Project: $PROJECT_ID in Region: $REGION"
gcloud config set project "$PROJECT_ID"

echo "==> Enabling required GCP APIs..."
gcloud services enable \
    alloydb.googleapis.com \
    compute.googleapis.com \
    cloudresourcemanager.googleapis.com \
    servicenetworking.googleapis.com \
    aiplatform.googleapis.com

echo "==> Configuring Private Services Access (PSA) VPC Peering..."
if ! gcloud compute addresses describe psa-range --global &>/dev/null; then
    gcloud compute addresses create psa-range \
        --global \
        --purpose=VPC_PEERING \
        --prefix-length=24 \
        --description="VPC private service access for AlloyDB" \
        --network=default
fi

gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=psa-range \
    --network=default || true

echo "==> Generating secure database credentials..."
export PGPASSWORD="${PGPASSWORD:-$(openssl rand -hex 16)}"
echo "Database Password: $PGPASSWORD"
echo "$PGPASSWORD" > .pgpassword
chmod 600 .pgpassword

echo "==> Creating AlloyDB Cluster: $ADBCLUSTER..."
gcloud alloydb clusters create "$ADBCLUSTER" \
    --password="$PGPASSWORD" \
    --network=default \
    --region="$REGION" \
    --subscription-type=TRIAL

echo "==> Creating AlloyDB Primary Instance with 8 vCPUs..."
gcloud alloydb instances create "${ADBCLUSTER}-pr" \
    --instance-type=PRIMARY \
    --cpu-count=8 \
    --region="$REGION" \
    --cluster="$ADBCLUSTER"

echo "==> Enabling faster embedding generation database flag..."
gcloud beta alloydb instances update "${ADBCLUSTER}-pr" \
    --database-flags google_ml_integration.enable_faster_embedding_generation=on \
    --region="$REGION" \
    --cluster="$ADBCLUSTER" \
    --project="$PROJECT_ID" \
    --update-mode=FORCE_APPLY

echo "==> Binding IAM roles for Vertex AI invocation by AlloyDB service agent..."
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-alloydb.iam.gserviceaccount.com" \
    --role="roles/aiplatform.user"

echo "==> Creating Compute Engine Client VM: $GCEVM..."
gcloud compute instances create "$GCEVM" \
    --zone="$ZONE" \
    --create-disk=auto-delete=yes,boot=yes,image=projects/debian-cloud/global/images/"$(gcloud compute images list --filter="family=debian-13 AND family!=debian-13-arm64" --format="value(name)" | head -n 1)" \
    --scopes=https://www.googleapis.com/auth/cloud-platform

echo "==> Infrastructure setup complete."
INSTANCE_IP=$(gcloud alloydb instances describe "${ADBCLUSTER}-pr" --cluster="$ADBCLUSTER" --region="$REGION" --format="value(ipAddress)")
echo "AlloyDB Instance Private IP: $INSTANCE_IP"
