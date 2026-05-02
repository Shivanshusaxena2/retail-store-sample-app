# =============================================================================
# LOCAL VALUES - DR ENVIRONMENT (AZURE)
# =============================================================================

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  cluster_name = "${var.cluster_name}-${random_string.suffix.result}"
  acr_name     = "${var.acr_name}${random_string.suffix.result}"

  common_tags = {
    Environment = var.environment
    Project     = "retail-store"
    ManagedBy   = "terraform"
    CreatedBy   = "TrainWithShubhamCommunity"
    Purpose     = "disaster-recovery"
  }

  services = ["ui", "catalog", "cart", "checkout", "orders"]
}
