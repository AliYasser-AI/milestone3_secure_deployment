# WAF Rules — Azure Application Gateway (WAF_v2)

Defined in `iac/terraform/modules/waf/main.tf`. Mode: **Prevention** (blocks, not just logs).

## Managed rules
- **OWASP Core Rule Set 3.2** — covers SQLi, XSS, remote code execution, protocol
  anomalies, and generic injection patterns across all traffic to the API.
- One tuned exclusion on the `TransactionAmt` request argument to avoid false
  positives on legitimate numeric fraud-feature payloads, without disabling
  the underlying rule set.

## Custom rules
| Priority | Name | Trigger | Action |
|---|---|---|---|
| 1 | `RateLimitAuthEndpoint` | > 60 requests/min per client IP to `/api/v1/auth/token` | Block |
| 2 | `BlockNonJsonInference` | Request to `/api/v1/inference/predict` without `Content-Type: application/json` | Block |
| 3 | `BlockDisallowedGeos` | Request from a country code in `blocked_country_codes` (disabled by default — enable and populate once the expected client geography is confirmed) | Block |

## Defence in depth
The WAF is one of three independent layers protecting the inference endpoint:
1. **WAF (network edge)** — custom rules above + OWASP CRS
2. **Application-level rate limiting** — SlowAPI (30/min general, 5/min on login)
3. **Input validation** — Pydantic `extra="forbid"` + field bounds

Losing any single layer still leaves the other two in place.

## Operational notes
- `request_body_check = true`, `max_request_body_size_in_kb = 128`,
  `file_upload_limit_in_mb = 10` — bounds resource consumption per request.
- TLS policy on the Application Gateway listener: `AppGwSslPolicy20220101S`
  (TLS 1.2 minimum, modern cipher suites only). Upgrade to a TLS-1.3-only
  predefined policy once available in the target Azure region.
- All WAF block/allow events flow into the Log Analytics workspace defined
  in `modules/monitoring`, alongside Key Vault and AKS diagnostics — see
  `docs/Security_Architecture_Documentation.docx`.
