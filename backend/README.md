# Favour Live Price Gateway

This backend is the server-side live-price boundary used by the Favour Android app.

## Flow

Favour Android -> POST /compare -> authorised retailer/source adapters -> normalized offers -> Favour.

The Android app sends:
- query
- normalized product
- 6-digit pincode

The gateway returns:
```json
{
  "offers": [
    {
      "id": "source-item-id",
      "retailer": "blinkit",
      "price": 42.0,
      "available": true,
      "checkedAt": "2026-10-03T10:00:00Z",
      "source": "authorised source",
      "deliveryFee": 0,
      "handlingFee": 0,
      "otherFee": 0
    }
  ]
}
```

## Endpoints

- `GET /` - service status and configured retailer count
- `GET /health` - health check
- `GET /sources` - configured-source status
- `POST /compare` - live comparison

## Environment variables

Set `FAVOUR_GATEWAY_TOKEN` to protect the mobile-to-gateway API.

Each retailer can have its own authorised upstream JSON endpoint:

- `FAVOUR_SOURCE_BLINKIT`
- `FAVOUR_SOURCE_ZEPTO`
- `FAVOUR_SOURCE_SWIGGYINSTMART`
- `FAVOUR_SOURCE_BIGBASKETNOW`
- `FAVOUR_SOURCE_FLIPKARTMINUTES`
- `FAVOUR_SOURCE_AMAZONNOW`
- `FAVOUR_SOURCE_JIOMART`

### Swiggy Instamart MCP

The gateway also supports the official Swiggy Builders Club Instamart MCP `search_products` tool.

Set:
- `FAVOUR_SWIGGY_ACCESS_TOKEN` - Swiggy OAuth access token
- `FAVOUR_SWIGGY_ADDRESS_ID` - selected saved Swiggy delivery address ID

The gateway calls `POST https://mcp.swiggy.com/im` with the authenticated user's token and the `search_products` tool, then converts matching pack-size variations into Favour offers.

Swiggy MCP production access is invite/review based. Build and staging access should be completed before production. OAuth 2.1 with PKCE is required; access tokens are time-limited. Do not commit tokens to GitHub.

Each configured generic source receives the standard query/product/pincode POST contract and must return `{"offers":[...]}` or `{"data":{"offers":[...]}}`.

## Deployment

The backend is a FastAPI service and can be deployed as a Render Web Service using the included Dockerfile/render.yaml.

## Important

This gateway does not contain CAPTCHA bypasses, login automation, anti-bot workarounds, or scraping of protected/private endpoints. Retailer adapters must use an authorised/public/partner source or another permitted data source.

Actual retailer prices appear only after an authorised source is configured.

## Local test

```bash
pip install -r backend/requirements.txt
uvicorn app.main:app --reload --port 8000
```

Backend contract version: 1.1.0.
