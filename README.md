# Favour v4

Personal shopping comparison app.

Favour is a local-first Android grocery comparison assistant. It parses a
typed product and pack, normalizes g/kg, ml/L, pieces, and multipacks, then
compares saved observations across retailers. It includes saved products,
Smart Basket totals and allocation, local price history, target-price alerts,
and PIN-code storage.

Supported retailers: Blinkit, Zepto, Swiggy Instamart, BigBasket Now,
Flipkart Minutes, Amazon Now, and JioMart.

The retailer adapter boundary can add official/authorized retailer APIs when
available. This repository currently has no authorised live retailer feed, so
each retailer is shown as **Not available** until a user opens it and records a
price, or imports a gallery screenshot. Screenshot OCR is a convenience aid;
the user must confirm every OCR value before it is stored as a Screenshot
observation. Favour does not scrape, bypass protections, fabricate prices, or
send user data to a backend. Delivery/handling/other fees are included only
when explicitly recorded.
