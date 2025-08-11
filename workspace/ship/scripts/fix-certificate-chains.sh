#!/bin/bash

# Script to create full certificate chains from individual certs and intermediate zips

set -euo pipefail

CERTS_DIR="/etc/nginx/certs"

# Function to create fullchain certificate
create_fullchain() {
    local domain="$1"
    local cert_prefix="$2"
    
    echo "Processing $domain..."
    
    cd "${CERTS_DIR}/${domain}"
    
    # Extract intermediate certificates if zip exists
    if [[ -f "_.${cert_prefix}_ssl_certificate_INTERMEDIATE.zip" ]]; then
        unzip -o "_.${cert_prefix}_ssl_certificate_INTERMEDIATE.zip"
        
        # Create fullchain certificate
        cat "${cert_prefix}_ssl_certificate.cer" intermediate*.cer > "${cert_prefix}_fullchain.cer"
        echo "Created ${cert_prefix}_fullchain.cer"
    else
        echo "No intermediate certificates found for $domain"
    fi
}

# Process each domain
create_fullchain "iLegalFlow.com" "ilegalflow.com"
create_fullchain "Crypto-Fakes.com" "crypto-fakes.com"
create_fullchain "Cutie-Traders.com" "cutie-traders.com"
create_fullchain "CutieTraders.com" "cutietraders.com"
create_fullchain "iMediFlow.com" "imediflow.com"

echo "Certificate chain processing complete!"