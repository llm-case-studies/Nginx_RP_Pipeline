#!/bin/bash
# validate-ionos-emulation.sh
# Validates that local emulation matches IONOS production structure

set -euo pipefail

ERRORS=0

echo "🔍 Validating IONOS emulation setup..."

# Check users exist
for user in deploy nodeuser pythonuser proxyuser; do
    if id "$user" &>/dev/null; then
        echo "✅ User $user exists"
    else
        echo "❌ User $user missing"
        ((ERRORS++))
    fi
done

# Check groups exist
for group in pipeline-all pipeline-stage pipeline-prod pronunco-style; do
    if getent group "$group" &>/dev/null; then
        echo "✅ Group $group exists"
    else
        echo "❌ Group $group missing"
        ((ERRORS++))
    fi
done

# Check group memberships
declare -A expected_groups=(
    ["deploy"]="deploy docker pipeline-all pipeline-stage pronunco-style"
    ["nodeuser"]="nodeuser pipeline-all pipeline-prod pronunco-style"  
    ["pythonuser"]="pythonuser pipeline-all pipeline-prod pronunco-style"
    ["proxyuser"]="proxyuser users docker pipeline-all pipeline-prod pronunco-style"
)

for user in "${!expected_groups[@]}"; do
    actual_groups=$(groups "$user" 2>/dev/null | cut -d: -f2 | tr ' ' '\n' | sort | tr '\n' ' ')
    expected="${expected_groups[$user]}"
    
    for group in $expected; do
        if echo "$actual_groups" | grep -q "\b$group\b"; then
            echo "✅ $user is in $group"
        else
            echo "❌ $user missing from $group"
            ((ERRORS++))
        fi
    done
done

# Check directory structure
declare -A expected_dirs=(
    ["/home/deploy/Live-Mirror"]="deploy:deploy"
    ["/home/deploy/pre-prod-stage/proxyuser"]="deploy:deploy"
    ["/home/proxyuser/NgNx-RP"]="proxyuser:proxyuser"
    ["/home/proxyuser/pre-prod"]="proxyuser:proxyuser"
    ["/home/nodeuser/nodejs-apps"]="nodeuser:nodeuser"
    ["/home/pythonuser/python-apps"]="pythonuser:pythonuser"
)

for dir in "${!expected_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        owner=$(stat -c %U:%G "$dir")
        expected="${expected_dirs[$dir]}"
        if [[ "$owner" == "$expected" ]]; then
            echo "✅ $dir exists with correct ownership ($owner)"
        else
            echo "❌ $dir has incorrect ownership. Expected: $expected, Actual: $owner"
            ((ERRORS++))
        fi
    else
        echo "❌ Directory $dir missing"
        ((ERRORS++))
    fi
done

# Test pipeline team logic
echo ""
echo "🧪 Testing pipeline team detection logic..."
for user in deploy nodeuser pythonuser proxyuser; do
    if groups "$user" | grep -q "pipeline-"; then
        echo "✅ $user detected as pipeline team member"
        
        if groups "$user" | grep -q "pipeline-stage"; then
            echo "   └─ ✅ $user has staging access"
        fi
        
        if groups "$user" | grep -q "pipeline-prod"; then
            echo "   └─ ✅ $user has production access"
        fi
    else
        echo "❌ $user not detected as pipeline team member"
        ((ERRORS++))
    fi
done

echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo "🎉 All validation checks passed! Local emulation matches IONOS structure."
    exit 0
else
    echo "❌ $ERRORS validation errors found. Please fix before proceeding."
    exit 1
fi