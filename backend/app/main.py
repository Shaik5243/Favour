import asyncio
import os
from typing import Any

import httpx
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(title="Favour Live Price Gateway", version="1.0.0")


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
    configured = [r for r, url in source_urls().items() if url]
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
            retailer: {"configured": bool(url)}
            for retailer, url in source_urls().items()
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
    if not any(urls.values()):
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
        batches = await asyncio.gather(
            *[
                query_source(client, retailer, request)
                for retailer in RETAILERS
                if urls[retailer]
            ]
        )

    return CompareResponse(
        offers=[offer for batch in batches for offer in batch]
    )
