# Rate Limiting Implementation

This document describes the rate limiting implementation added to protect against brute force login attacks.

## Implementation Overview

The rate limiting solution uses multiple layers of protection:

1. **AWS WAF v2** - Primary rate limiting with intelligent rules
2. **API Gateway Throttling** - Backup rate limiting and general protection
3. **Enhanced Logging** - Security monitoring and alerting

## WAF Rules

### Login-Specific Rate Limiting
- **Limit**: 10 requests per 5-minute window per IP address
- **Scope**: POST requests containing `username=` in the body
- **Action**: Block requests that exceed the limit

### General Rate Limiting  
- **Limit**: 50 requests per 5-minute window per IP address
- **Scope**: All requests to the API
- **Action**: Block requests that exceed the limit

## API Gateway Protection

- **Rate Limit**: 100 requests per second
- **Burst Capacity**: 200 requests
- **Access Logging**: Enabled with security-focused fields

## Security Logging

Enhanced logging captures:
- Client IP address
- User agent string
- Username (for audit trails)
- Failure reason (invalid username, password, or MFA)
- Timestamp (ISO 8601 format)

### Log Format Example
```json
{
  "level": "WARN",
  "message": "LOGIN_FAILED",
  "reason": "INVALID_PASSWORD",
  "username": "user@example.com", 
  "clientIp": "192.168.1.100",
  "userAgent": "Mozilla/5.0...",
  "timestamp": "2025-01-01T12:00:00.000Z"
}
```

## Monitoring & Alerting

CloudWatch alarms monitor:
- Failed login attempts (threshold: 5 in 5 minutes)
- WAF blocks (immediate notification)

## Testing Rate Limits

To test the implementation:

```bash
# Run basic auth logic tests
cd src
node test-rate-limit.js
```

## Usability Impact

**Minimal Impact for Legitimate Users**:
- Normal users unlikely to hit 10 login attempts in 5 minutes
- Failed attempts only count for the specific IP address
- No impact on successful logins or page views

**Protection Against Attacks**:
- Distributed attacks still limited per IP
- Aggressive scanning blocked at 50 req/5min threshold
- Real-time monitoring and alerting

## Configuration

Rate limits can be adjusted in `waf.tf`:
- `limit = 10` for login attempts
- `limit = 50` for general requests
- Time window is always 5 minutes (AWS WAF fixed)

API Gateway limits in `api.tf`:
- `rate_limit = 100` (requests per second)
- `burst_limit = 200` (burst capacity)

## Security Considerations

- Rate limits are per source IP (IPv4/IPv6)
- WAF rules specifically target login POST requests
- Logging includes security context for forensic analysis
- CloudWatch retention prevents log bloat (14-30 days)