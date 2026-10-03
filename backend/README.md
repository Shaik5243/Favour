# Favour Live Price Gateway

Favour uses a provider-neutral gateway so the Android app does not depend on a paid aggregator.

## Request
POST /compare

```json
{"query":"Amul Milk 500ml","product":{"name":"Milk","brand":"Amul","packSize":500,"unit":"millilitre","packCount":1},"pincode":"560001"}
```

Optional authentication: `Authorization: Bearer <token>`.

## Response
```json
{"offers":[{"id":"blinkit-123","retailer":"blinkit","price":31,"available":true,"checkedAt":"2026-10-03T08:00:00Z","source":"retailer-adapter","deliveryFee":0,"handlingFee":0,"otherFee":0}]}
```

Retailer values must match Favour's `Retailer` enum.

## Adapter boundary
Each retailer adapter should implement its own permitted data-access method and return the normalized offer contract. The gateway owns location handling, retries, normalization, matching, caching, and the lowest-effective-price calculation.

Do not bypass CAPTCHA, authentication, access controls, robots restrictions, or retailer terms. Where a retailer does not provide an authorized machine-readable source, the adapter should remain unavailable rather than scraping around controls.

## Planned flow
Android -> Favour gateway -> retailer adapters -> normalize SKU/pack -> validate availability -> calculate effective cost -> Android.

This keeps the app independent from QuickCommerce API and allows a permitted adapter to be added without changing the Android UI.