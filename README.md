# Chabok API contracts

Authoritative OpenAPI 3.1 contracts for the Chabok platform APIs:

- IAM
- Consignments
- Manifests
- Dashboard
- Service Catalog
- Pricing
- Geography
- Operations
- Network
- Fleet
- CRM

## Validate contracts

```powershell
npm ci
npm run lint
```

The Branch Panel repository commits generated TypeScript types derived from
these contracts. Contract changes should be merged first and identified by an
immutable Git tag before dependent backend or frontend releases are approved.

## Local Swagger UI

Clone these repositories as siblings:

```text
chabok-api-contracts/
chabok-platform-backend/
chabok-platform-infrastructure/
```

Then run from `chabok-platform-infrastructure`:

```powershell
docker compose --profile docs up -d swagger-ui
```

Open `http://localhost:8081`. The Swagger container serves these local YAML
files and proxies Try-it-out requests to the local backend. It is a local-only
tool and must not be exposed as a production service.

## Backend route conformance

Export Laravel's API route inventory as JSON, then run:

```powershell
./scripts/validate-implemented-routes.ps1 -RouteInventoryPath <routes.json>
```

No API credentials, environment files or production secrets belong in this
repository.
