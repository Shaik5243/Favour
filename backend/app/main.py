import asyncio
import os
import re
from datetime import datetime, timezone
from typing import Any

import httpx
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(title="Favour Live Price Gateway", version="1.1.0")


class Product(BaseModel):
    id: str
    name: str
    brand: str = ""
    packSize: float = 1
    unit: str = "piece"
    packCount: int = 1


class CompareRequest(BaseModel):
    query: str = Field(min_length=1)
    product: Product
    pincode: str = Field(pattern=r"^\d{6}$")


class Offer(BaseModel):
    id: str
    retailer: str
    price: float = Field(gt=0)
    available: bool = True
    checkedAt: str
    source: str
    deliveryFee: float | None = None
    handlingFee: float | None = None
    otherFee: float | None = None


class CompareResponse(BaseModel):
    offers: list[Offer]


RETAILERS = (
    "blinkit",
    "zepto",
    "swiggyInstamart",
    "bigBasketNow",
    "flipkartMinutes",
    "amazonNow",
    "jioMart",
)


def source_url(retailer: str) -> str:
    return os.getenv(f"FAVOUR_SOURCE_{retailer.upper()}", "").strip()


def swiggy_configured() -> bool:
    return bool(
        os.getenv("FAVOUR_SWIGGY_ACCESS_TOKEN", "").strip()
        and os.getenv("FAVOUR_SWIGGY_ADDRESS_ID", "").strip()
    )


def flipkart_configured() -> bool:
    return bool(
        os.getenv("FAVOUR_FLIPKART_AFFILIATE_ID", "").strip()
        and os.getenv("FAVOUR_FLIPKART_AFFILIATE_TOKEN", "").strip()
    )


def configured_retailers() -> list[str]:
    configured = [r for r, url in source_urls().items() if url]
    if swiggy_configured() and "swiggyInstamart" not in configured:
        configured.append("swiggyInstamart")
    if flipkart_configured() and "flipkartMinutes" not in configured:
        configured.append("flipkartMinutes")
    return configured


def source_urls() -> dict[str, str]:
    return {retailer: source_url(retailer) for retailer in RETAILERS}


def _number(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def normalize_offer(item: dict[str, Any], retailer: str) -> Offer | None:
    try:
        price = float(item.get("price"))
    except (TypeError, ValueError):
        return None
    if price <= 0:
        return None
    return Offer(
        id=str(item.get("id") or f"{retailer}-{abs(hash(str(item)))}"),
        retailer=retailer,
        price=price,
        available=item.get("available", True) is not False,
        checkedAt=str(item.get("checkedAt") or item.get("checked_at") or ""),
        source=str(item.get("source") or "authorised gateway source"),
        deliveryFee=_number(item.get("deliveryFee", item.get("delivery_fee"))),
        handlingFee=_number(item.get("handlingFee", item.get("handling_fee"))),
        otherFee=_number(item.get("otherFee", item.get("other_fee"))),
    )


def _unit_aliases(unit: str) -> set[str]:
    return {
        "kilogram": {"kg", "kgs", "kilogram", "kilograms"},
        "gram": {"g", "gm", "gms", "gram", "grams"},
        "litre": {"l", "lt", "ltr", "litre", "litres", "liter", "liters"},
        "millilitre": {"ml", "millilitre", "millilitres", "milliliter", "milliliters"},
        "piece": {"pc", "pcs", "piece", "pieces", "pack", "packs"},
    }.get(unit, {unit})


def _quantity_matches(text: str, product: Product) -> bool:
    if product.packSize <= 0:
        return True
    aliases = "|".join(re.escape(item) for item in _unit_aliases(product.unit))
    pattern = re.compile(
        rf"(?<!\d){re.escape(str(product.packSize).rstrip('0').rstrip('.'))}"
        rf"\s*(?:{aliases})\b",
        re.IGNORECASE,
    )
    if pattern.search(text):
        return True
    # Common conversion: 1 kg may be returned as 1000 g, etc.
    conversions = {
        "kilogram": product.packSize * 1000,
        "gram": product.packSize / 1000,
        "litre": product.packSize * 1000,
        "millilitre": product.packSize / 1000,
    }
    converted = conversions.get(product.unit)
    if converted is None:
        return False
    converted_text = str(converted).rstrip("0").rstrip(".")
    other_unit = "g" if product.unit == "kilogram" else "kg" if product.unit == "gram" else "ml" if product.unit == "litre" else "l"
    return bool(
        re.search(
            rf"(?<!\d){re.escape(converted_text)}\s*{re.escape(other_unit)}\b",
            text,
            re.IGNORECASE,
        )
    )


def _extract_swiggy_offers(decoded: Any, request: CompareRequest) -> list[Offer]:
    if not isinstance(decoded, dict):
        return []
    if decoded.get("success") is False:
        return []

    data = decoded.get("data")
    if not isinstance(data, dict):
        return []

    products = data.get("products")
    if not isinstance(products, list):
        return []

    checked_at = datetime.now(timezone.utc).isoformat()
    offers: list[Offer] = []

    for product in products:
        if not isinstance(product, dict):
            continue
        product_name = str(product.get("name") or "")
        brand = str(product.get("brand") or "")
        variations = product.get("variations")
        if not isinstance(variations, list):
            variations = product.get("variants")
        if not isinstance(variations, list):
            variations = []

        for index, variation in enumerate(variations):
            if not isinstance(variation, dict):
                continue
            quantity = str(
                variation.get("quantity")
                or variation.get("quantityDescription")
                or variation.get("name")
                or ""
            )
            combined = " ".join(part for part in (brand, product_name, quantity) if part)
            if not _quantity_matches(combined, request.product):
                continue
            price = _number(
                variation.get("price")
                or variation.get("sellingPrice")
                or variation.get("salePrice")
            )
            if price is None or price <= 0:
                continue
            spin_id = str(variation.get("spinId") or variation.get("id") or index)
            in_stock = variation.get("inStock")
            available = in_stock is not False and product.get("available") is not False
            offers.append(
                Offer(
                    id=f"swiggyInstamart-{spin_id}",
                    retailer="swiggyInstamart",
                    price=price,
                    available=available,
                    checkedAt=checked_at,
                    source="Swiggy Instamart MCP",
                )
            )
    return offers


async def query_swiggy_instamart(
    client: httpx.AsyncClient,
    request: CompareRequest,
) -> list[Offer]:
    access_token = os.getenv("FAVOUR_SWIGGY_ACCESS_TOKEN", "").strip()
    address_id = os.getenv("FAVOUR_SWIGGY_ADDRESS_ID", "").strip()
    if not access_token or not address_id:
        return []

    payload = {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": "search_products",
            "arguments": {
                "addressId": address_id,
                "query": request.query,
            },
        },
        "id": 1,
    }
    try:
        response = await client.post(
            "https://mcp.swiggy.com/im",
            headers={
                "Accept": "application/json",
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json",
            },
            json=payload,
            timeout=20,
        )
        response.raise_for_status()
        return _extract_swiggy_offers(response.json(), request)
    except (httpx.HTTPError, ValueError):
        return []


async def query_flipkart(
    client: httpx.AsyncClient,
    request: CompareRequest,
) -> list[Offer]:
    affiliate_id = os.getenv("FAVOUR_FLIPKART_AFFILIATE_ID", "").strip()
    affiliate_token = os.getenv("FAVOUR_FLIPKART_AFFILIATE_TOKEN", "").strip()
    if not affiliate_id or not affiliate_token:
        return []

    try:
        response = await client.get(
            "https://affiliate-api.flipkart.net/affiliate/1.0/search.json",
            params={"query": request.query, "resultCount": "10"},
            headers={
                "Accept": "application/json",
                "Fk-Affiliate-Id": affiliate_id,
                "Fk-Affiliate-Token": affiliate_token,
            },
            timeout=15,
        )
        response.raise_for_status()
        decoded = response.json()
    except (httpx.HTTPError, ValueError):
        return []

    products = decoded.get("productInfoList") if isinstance(decoded, dict) else None
    if not isinstance(products, list):
        return []

    offers: list[Offer] = []
    checked_at = datetime.now(timezone.utc).isoformat()
    for item in products:
        if not isinstance(item, dict):
            continue
        base = item.get("productBaseInfoV1")
        if not isinstance(base, dict):
            continue
        price_data = base.get("price")
        if not isinstance(price_data, dict):
            continue
        price = _number(
            price_data.get("sellingPrice")
            or price_data.get("specialPrice")
            or price_data.get("price")
        )
        if price is None or price <= 0:
            continue
        product_id = str(base.get("productId") or "")
        if not product_id:
            continue
        product_url = str(base.get("productUrl") or "")
        offers.append(
            Offer(
                id=f"flipkartMinutes-{product_id}",
                retailer="flipkartMinutes",
                price=price,
                available=True,
                checkedAt=checked_at,
                source="Flipkart Affiliate API",
                otherFee=None,
            )
        )
    return offers


async def query_source(
    client: httpx.AsyncClient,
    retailer: str,
    request: CompareRequest,
) -> list[Offer]:
    url = source_url(retailer)
    if not url:
        return []

    payload = {
        "query": request.query,
        "product": request.product.model_dump(),
        "pincode": request.pincode,
    }

    try:
        response = await client.post(url, json=payload, timeout=12)
        response.raise_for_status()
        decoded = response.json()
    except (httpx.HTTPError, ValueError):
        return []

    raw: Any = decoded
    if isinstance(decoded, dict):
        raw = decoded.get("offers")
        if raw is None and isinstance(decoded.get("data"), dict):
            raw = decoded["data"].get("offers")

    if not isinstance(raw, list):
        return []

    offers: list[Offer] = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        offer = normalize_offer(item, retailer)
        if offer is not None:
            offers.append(offer)
    return offers


@app.get("/")
async def root() -> dict[str, Any]:
    configured = configured_retailers()
    return {
        "service": "Favour Live Price Gateway",
        "status": "ok",
        "configuredRetailers": configured,
        "retailerCount": len(configured),
    }


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/sources")
async def sources() -> dict[str, Any]:
    return {
        "retailers": {
            retailer: {
                "configured": retailer in configured_retailers(),
                "mode": (
                    "swiggy-mcp"
                    if retailer == "swiggyInstamart" and swiggy_configured()
                    else "flipkart-affiliate"
                    if retailer == "flipkartMinutes" and flipkart_configured()
                    else "http-source"
                ),
            }
            for retailer in RETAILERS
        }
    }


@app.post("/compare", response_model=CompareResponse)
async def compare(
    request: CompareRequest,
    authorization: str | None = Header(default=None),
) -> CompareResponse:
    token = os.getenv("FAVOUR_GATEWAY_TOKEN", "").strip()
    if token and authorization != f"Bearer {token}":
        raise HTTPException(status_code=401, detail="Invalid gateway token")

    urls = source_urls()
    if not any(urls.values()) and not swiggy_configured() and not flipkart_configured():
        raise HTTPException(
            status_code=503,
            detail="No authorised retailer sources are configured",
        )

    async with httpx.AsyncClient(
        headers={
            "Accept": "application/json",
            "User-Agent": "FavourGateway/1.0",
        }
    ) as client:
        tasks = [
            query_source(client, retailer, request)
            for retailer in RETAILERS
            if urls[retailer]
        ]
        if swiggy_configured():
            tasks.append(query_swiggy_instamart(client, request))
        if flipkart_configured():
            tasks.append(query_flipkart(client, request))
        batches = await asyncio.gather(*tasks)

    return CompareResponse(
        offers=[offer for batch in batches for offer in batch]
    )
