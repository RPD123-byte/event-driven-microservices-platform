#!/usr/bin/env bash
# destroy.sh – tears down the EDMP infrastructure deployed by deploy.sh
# -----------------------------------------------------------------------
# • Reads backend configuration from .terraform-backend-info
# • Executes terraform destroy -auto-approve
# • NEVER destroys the S3 bucket and DynamoDB table (state storage)
# • Leaves the local SSH key-pair in place (delete manually if desired)
#
# Usage:
#   $ ./destroy.sh
# -----------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# ──────────────────────────────────────────────────────────────
# 1️⃣  read backend configuration
# ──────────────────────────────────────────────────────────────
if [[ ! -f ".terraform-backend-info" ]]; then
    echo "❌  Backend info file not found. Run deploy.sh first."
    exit 1
fi

source .terraform-backend-info

echo "🔧  Using backend configuration:"
echo "    S3 Bucket: $BUCKET_NAME"
echo "    DynamoDB: $DYNAMODB_TABLE"
echo "    Region: $REGION"
echo "    Key Pair: ${KEY_PAIR_NAME:-edmp-key}"

# ──────────────────────────────────────────────────────────────
# 2️⃣  destroy terraform resources
# ──────────────────────────────────────────────────────────────
cd terraform

# Get AWS credentials from CLI for Terraform (SSO workaround)
echo "🔐  Setting up AWS credentials for Terraform..."
eval "$(aws configure export-credentials --profile ${AWS_PROFILE:-default} --format env)"

echo "⚠️  Destroying Terraform-managed resources..."
terraform init \
  -backend-config="bucket=${BUCKET_NAME}" \
  -backend-config="key=edmp/terraform.tfstate" \
  -backend-config="region=${REGION}" \
  -backend-config="encrypt=true" \
  -backend-config="dynamodb_table=${DYNAMODB_TABLE}" \
  -backend-config="workspace_key_prefix=edmp" \
  -upgrade -input=false >/dev/null

terraform destroy -var="aws_region=${REGION}" -var="key_pair_name=${KEY_PAIR_NAME:-edmp-key}" -auto-approve

# ──────────────────────────────────────────────────────────────
# 3️⃣  cleanup AWS key pair
# ──────────────────────────────────────────────────────────────
echo "🗑️  Deleting AWS key pair '${KEY_PAIR_NAME:-edmp-key}'..."
aws ec2 delete-key-pair --key-name "${KEY_PAIR_NAME:-edmp-key}" --region "$REGION" 2>/dev/null || echo "    Key pair already deleted or not found."

# ──────────────────────────────────────────────────────────────
# 4️⃣  backend resources are NEVER deleted (they store terraform state)
# ──────────────────────────────────────────────────────────────
echo "ℹ️  Backend resources (S3 bucket and DynamoDB table) are preserved."
echo "    These contain your terraform state and should never be deleted."
echo "    S3 Bucket: $BUCKET_NAME"
echo "    DynamoDB: $DYNAMODB_TABLE"

# ──────────────────────────────────────────────────────────────
# 5️⃣  completion message
# ──────────────────────────────────────────────────────────────
echo ""
echo "✅  Terraform destroy complete."
echo "🔑  Local SSH key-pair left untouched:"
echo "    terraform/edmp-key      (private key)"
echo "    terraform/edmp-key.pub  (public key)"
echo "🗑️  AWS key pair '${KEY_PAIR_NAME:-edmp-key}' has been deleted."
echo ""
echo "⚠️  IMPORTANT: Backend state resources are preserved and should never be deleted."
echo "    They contain your terraform state and are required for future deployments."

cd ..