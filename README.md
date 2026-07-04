# Milestone 3 — Secure Deployment
**Owner:** Ali Yasser — Security & DevSecOps Engineer
**Project:** Secure & Compliant ML Security Pipeline (IEEE-CIS Fraud Detection)

## Deliverables checklist

| Deliverable | Location | Status |
|---|---|---|
| Securely Deployed Service (code) | `app/`, `Dockerfile`, `k8s/` | Built, tested locally |
| IaC (Terraform) for AKS + Key Vault + AppGW WAF + Defender | `iac/terraform/` | Syntax + reference-validated |
| Security Architecture Docs (network diagram, Key Vault guide, STRIDE) | `docs/Security_Architecture_Documentation.docx` | Done |
| WAF rules summary | `docs/WAF_Rules.md` | Done |
| Penetration Test Report | `pentest/Penetration_Test_Report_Milestone3.docx` | 10 tests run, 2 findings remediated, 1 tracked |

## What's real vs. what's a template
- **`app/`, `Dockerfile`, `k8s/`** — actual working code. The FastAPI service was run locally, and every
  control described in the pentest report (auth enforcement, rate limiting, input validation, header
  hardening) was tested against a live instance, not just reviewed on paper.
- **`iac/terraform/`** — complete, internally consistent Terraform (validated for HCL syntax and that every
  variable reference resolves). It has **not** been run against a real Azure subscription — that requires
  your Azure credentials/subscription and is the natural next step once you're ready to provision.
- **Docs** — written to reflect the actual architecture defined in the Terraform and the actual test results
  from the pentest run; not generic filler.

## Project structure
```
app/                     FastAPI inference service
Dockerfile
k8s/                      Kubernetes manifests: namespace, workload-identity ServiceAccount,
                          Deployment/Service (hardened pod security context), NetworkPolicies
iac/terraform/            Full IaC: network, AKS, Key Vault, WAF/App Gateway, Defender for Cloud
docs/
  Security_Architecture_Documentation.docx   Network diagram + Key Vault guide + STRIDE threat model
  WAF_Rules.md                                WAF custom-rule reference
pentest/
  Penetration_Test_Report_Milestone3.docx     10-test manual assessment + OWASP API Top 10 mapping
```

## Local run
```bash
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload
```

## Deploying the infrastructure (when ready)
```bash
cd iac/terraform
cp terraform.tfvars.example terraform.tfvars   # fill in real values
export TF_VAR_jwt_secret_key="..."             # from a secrets manager, not a file
export TF_VAR_field_encryption_key="..."
terraform init
terraform plan
terraform apply
```
Then, once the AKS cluster exists:
```bash
az aks get-credentials --resource-group <rg> --name <aks-name>
kubectl apply -f k8s/
```

## Security controls implemented (maps to Milestone 3 tasks)
| Task | Where |
|---|---|
| AKS setup | `iac/terraform/modules/aks` — private cluster, Workload Identity, dedicated inference node pool |
| Azure Key Vault | `iac/terraform/modules/keyvault` — RBAC, private endpoint, no public access; `app/core/keyvault.py` for app-side access |
| OAuth2/JWT gateway | `app/core/security.py`, `app/api/auth.py` |
| Network hardening (NSGs, private endpoints, TLS, CORS) | `iac/terraform/modules/network`, `app/main.py` |
| Azure Defender for Cloud | `iac/terraform/modules/monitoring` |
| Penetration testing | `pentest/Penetration_Test_Report_Milestone3.docx` |
| WAF rules | `iac/terraform/modules/waf`, `docs/WAF_Rules.md` |
| IaC (Terraform) | `iac/terraform/` |

## Remaining before production sign-off
- [ ] Run `terraform apply` against the real Azure subscription and re-verify against a live endpoint
- [ ] Replace the local demo user store with Azure AD (Entra ID) — tracked as pentest finding F4
- [ ] Swap in Nour El-Din's real trained model artifact at `app/models/artifacts/`
- [ ] Re-run the pentest suite (Section 4 of the report) against the live AKS/AppGW endpoint with OWASP ZAP/Burp Suite
