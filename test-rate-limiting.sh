#!/bin/bash
# Manual verification script for rate limiting
# This script should be run AFTER Terraform deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration - Update these after deployment
API_ENDPOINT="https://vpn.barneyparker.com/"

echo -e "${YELLOW}Rate Limiting Verification Script${NC}"
echo "=================================="
echo ""

# Check if API endpoint is set
if [ "$API_ENDPOINT" = "https://vpn.barneyparker.com/" ]; then
    echo -e "${YELLOW}⚠️  Warning: Using default API endpoint${NC}"
    echo "   Update API_ENDPOINT in this script with your actual deployed endpoint"
    echo ""
fi

# Function to make a POST request
make_login_request() {
    local attempt=$1
    echo -n "Attempt $attempt: "
    
    response=$(curl -s -w "%{http_code}" -o /tmp/response_body.txt \
        -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "User-Agent: RateLimitTester/1.0" \
        -d "username=test@example.com&password=wrongpass&mfa=123456&desired=1" \
        "$API_ENDPOINT" 2>/dev/null || echo "000")
    
    if [ "$response" = "403" ]; then
        echo -e "${RED}BLOCKED (HTTP 403) - Rate limit working! ✓${NC}"
        return 1
    elif [ "$response" = "200" ] || [ "$response" = "303" ]; then
        echo -e "${GREEN}Request allowed (HTTP $response)${NC}"
        return 0
    else
        echo -e "${YELLOW}Unexpected response (HTTP $response)${NC}"
        return 2
    fi
}

echo "Testing rate limiting behavior..."
echo "This will make multiple failed login attempts to trigger WAF rules."
echo ""

blocked=false
for i in {1..15}; do
    if ! make_login_request $i; then
        blocked=true
        break
    fi
    sleep 1
done

echo ""
if [ "$blocked" = true ]; then
    echo -e "${GREEN}✓ SUCCESS: Rate limiting is working correctly${NC}"
    echo "  - Requests were blocked before reaching 15 attempts"
    echo "  - WAF rules are protecting against brute force attacks"
else
    echo -e "${RED}⚠️  WARNING: Rate limiting may not be working${NC}"
    echo "  - All 15 attempts were allowed"
    echo "  - Check WAF configuration and deployment"
fi

echo ""
echo "Manual verification steps:"
echo "1. Check CloudWatch logs for WAF blocks:"
echo "   aws logs filter-log-events --log-group-name /aws/wafv2/pwp-api-rate-limit"
echo ""
echo "2. Check Lambda logs for security events:"
echo "   aws logs filter-log-events --log-group-name /aws/lambda/pwp-asg-api --filter-pattern '\"LOGIN_FAILED\"'"
echo ""
echo "3. Monitor CloudWatch metrics:"
echo "   - PWP/Security/FailedLoginAttempts"
echo "   - PWP/Security/WAFBlocks"
echo ""

# Clean up
rm -f /tmp/response_body.txt

echo -e "${YELLOW}Verification complete!${NC}"