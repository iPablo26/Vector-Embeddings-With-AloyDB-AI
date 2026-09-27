#!/usr/bin/env bash
# ==============================================================================
# Script: 02_load_data.sh
# Description: Connects to AlloyDB from client VM and streams datasets from
#              Google Cloud Storage into PostgreSQL tables.
# ==============================================================================
set -euo pipefail

export REGION="${REGION:-us-central1}"
export ADBCLUSTER="${ADBCLUSTER:-alloydb-aip-01}"
export DB_NAME="quickstart_db"

INSTANCE_IP=$(gcloud alloydb instances describe "${ADBCLUSTER}-pr" --cluster="$ADBCLUSTER" --region="$REGION" --format="value(ipAddress)")
echo "Connecting to AlloyDB at $INSTANCE_IP..."

echo "==> Creating database '$DB_NAME'..."
psql "host=$INSTANCE_IP user=postgres" -c "CREATE DATABASE $DB_NAME" || true

echo "==> Enabling PostgreSQL extensions..."
psql "host=$INSTANCE_IP user=postgres dbname=$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS google_ml_integration CASCADE;"
psql "host=$INSTANCE_IP user=postgres dbname=$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS vector;"
psql "host=$INSTANCE_IP user=postgres dbname=$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS alloydb_scann;"

echo "==> Applying schema from Cloud Storage..."
gcloud storage cat gs://cloud-training/gcc/gcc-tech-004/cymbal_demo_schema.sql | psql "host=$INSTANCE_IP user=postgres dbname=$DB_NAME"

echo "==> Ingesting cymbal_products.csv (941 rows)..."
gcloud storage cat gs://cloud-training/gcc/gcc-tech-004/cymbal_products.csv | psql "host=$INSTANCE_IP user=postgres dbname=$DB_NAME" -c "\copy cymbal_products from stdin csv header"

echo "==> Ingesting cymbal_inventory.csv (263,861 rows)..."
gcloud storage cat gs://cloud-training/gcc/gcc-tech-004/cymbal_inventory.csv | psql "host=$INSTANCE_IP user=postgres dbname=$DB_NAME" -c "\copy cymbal_inventory from stdin csv header"

echo "==> Ingesting cymbal_stores.csv (4,654 rows)..."
gcloud storage cat gs://cloud-training/gcc/gcc-tech-004/cymbal_stores.csv | psql "host=$INSTANCE_IP user=postgres dbname=$DB_NAME" -c "\copy cymbal_stores from stdin csv header"

echo "==> Data ingestion successfully completed."
