#!/usr/bin/env bash
# ==============================================================================
# Script: 03_teardown.sh
# Description: Gracefully deprovisions AlloyDB cluster, backups, and VM to
#              prevent runaway cloud costs.
# ==============================================================================
set -euo pipefail

export PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"
export REGION="${REGION:-us-central1}"
export ZONE="${ZONE:-us-central1-a}"
export ADBCLUSTER="${ADBCLUSTER:-alloydb-aip-01}"
export GCEVM="${GCEVM:-instance-1}"

echo "==> Deleting AlloyDB Cluster: $ADBCLUSTER (Force includes primary instance)..."
gcloud alloydb clusters delete "$ADBCLUSTER" \
    --region="$REGION" \
    --force \
    --quiet || true

echo "==> Purging any automated AlloyDB backups for $ADBCLUSTER..."
for backup in $(gcloud alloydb backups list \
  --filter="CLUSTER_NAME: projects/$PROJECT_ID/locations/$REGION/clusters/$ADBCLUSTER" \
  --format="value(name)" \
  --sort-by=~createTime 2>/dev/null || true); do
    echo "Deleting backup $(basename "$backup")..."
    gcloud alloydb backups delete "$(basename "$backup")" --region "$REGION" --quiet || true
done

echo "==> Deleting Client Compute Engine VM: $GCEVM..."
gcloud compute instances delete "$GCEVM" \
    --zone="$ZONE" \
    --quiet || true

echo "==> Teardown complete. All temporary resources terminated."
