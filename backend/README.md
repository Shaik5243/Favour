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

Each configured source receives the standard query/product/pincode POST contract and must return `{"offers":[...]}` or `{"data":{"offers":[...]}}`.

## Deployment

The backend is a FastAPI service and can be deployed as a Render Web Service using the included Dockerfile/render.yaml. Render documents free Web Services and FastAPI deployment, with free services subject to inactivity spin-down.

## Important

This gateway does not contain CAPTCHA bypasses, login automation, anti-bot workarounds, or scraping of protected/private endpoints. Retailer adapters must use an authorised/public/partner source or another permitted data source.

The gateway is now a real deployable backend boundary, but actual retailer prices will appear only after at least one authorised retailer/source adapter is configured.

## Local test

```bash
pip install -r backend/requirements.txt
uvicorn app.main:app --reload --port 8000
```
