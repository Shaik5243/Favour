import asyncio
import os
import re
from urllib.parse import quote_plus
from datetime import datetime, timezone
from typing import Any

import httpx
from playwright.async_api import async_playwright
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(title="Favour Live Price Gateway", version="1.2.0")
_browser = None
_playwright = None
_browser_lock = asyncio.Lock()


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


def configured_retailers() -> list[str]:
    configured = [r for r, url in source_urls().items() if url]
    if swiggy_configured() and "swiggyInstamart" not in configured:
        configured.append("swiggyInstamart")
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



async def _get_browser():
    global _browser, _playwright
    async with _browser_lock:
        if _browser is None:
            _playwright = await async_playwright().start()
            _browser = await _playwright.chromium.launch(headless=True)
    return _browser


async def _geocode_pincode(client: httpx.AsyncClient, pincode: str) -> tuple[float, float] | None:
    try:
        response = await client.get(
            "https://nominatim.openstreetmap.org/search",
            params={"q": pincode + ", India", "format": "json", "limit": 1, "countrycodes": "in"},
            headers={"User-Agent": "Favour/1.0 personal shopping assistant"},
            timeout=8,
        )
        response.raise_for_status()
        rows = response.json()
        if rows:
            return float(rows[0]["lat"]), float(rows[0]["lon"])
    except (httpx.HTTPError, ValueError, KeyError, IndexError):
        pass
    return None


def _extract_price(value: Any) -> float | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value) if float(value) > 0 else None
    match = re.search(r"(\d+(?:\.\d+)?)", str(value).replace(",", ""))
    return float(match.group(1)) if match and float(match.group(1)) > 0 else None


def _walk_dicts(value: Any):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from _walk_dicts(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_dicts(child)


def _blinkit_offer_from_payload(payload: Any, request: CompareRequest) -> Offer | None:
    checked_at = datetime.now(timezone.utc).isoformat()
    for item in _walk_dicts(payload):
        price = _extract_price(
            item.get("price") or item.get("normal_price") or item.get("selling_price")
        )
        name = str(item.get("product_name") or item.get("name") or item.get("display_name") or "")
        quantity = str(
            item.get("unit") or item.get("quantity") or item.get("variant") or item.get("size") or ""
        )
        if not price or not _quantity_matches(" ".join((name, quantity)), request.product):
            continue
        available = (
            item.get("is_sold_out") is not True
            and str(item.get("product_state", "")).lower() != "sold_out"
        )
        product_id = str(item.get("product_id") or item.get("id") or abs(hash(str(item))))
        return Offer(
            id=f"blinkit-{product_id}",
            retailer="blinkit",
            price=price,
            available=available,
            checkedAt=checked_at,
            source="Blinkit website",
        )
    return None


async def query_blinkit(client: httpx.AsyncClient, request: CompareRequest) -> list[Offer]:
    coords = await _geocode_pincode(client, request.pincode)
    if coords is None:
        return []
    lat, lon = coords
    browser = await _get_browser()
    context = await browser.new_context(
        geolocation={"latitude": lat, "longitude": lon},
        permissions=["geolocation"],
        extra_http_headers={"Accept-Language": "en-IN,en;q=0.9"},
    )
    page = await context.new_page()
    payloads: list[Any] = []

    async def capture(response):
        if "/v1/layout/" not in response.url or "product" not in response.url:
            return
        try:
            if "application/json" in (response.headers.get("content-type") or ""):
                payloads.append(await response.json())
        except Exception:
            pass

    page.on("response", capture)
    try:
        await page.goto("https://blinkit.com/s/", wait_until="domcontentloaded", timeout=25000)
        await page.wait_for_timeout(2500)
        try:
            box = page.get_by_placeholder(re.compile("search", re.I))
            await box.fill(request.query)
            await page.keyboard.press("Enter")
        except Exception:
            await page.goto(
                "https://blinkit.com/s/?q=" + quote_plus(request.query),
                wait_until="domcontentloaded",
                timeout=25000,
            )
        await page.wait_for_timeout(4500)
    except Exception:
        return []
    finally:
        await context.close()

    for payload in payloads:
        offer = _blinkit_offer_from_payload(payload, request)
        if offer:
            return [offer]
    return []

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
    if not any(urls.values()) and not swiggy_configured():
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
        tasks.append(query_blinkit(client, request))
        if swiggy_configured():
            tasks.append(query_swiggy_instamart(client, request))
        batches = await asyncio.gather(*tasks)

    return CompareResponse(
        offers=[offer for batch in batches for offer in batch]
    )
