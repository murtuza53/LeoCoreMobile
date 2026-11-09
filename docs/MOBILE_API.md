# LeoCore Mobile API — Reference (v1)

For the mobile app team. **Current as of LeoCore ERP 1.6.52 (9 Nov 2026).** This is the complete
reference; the dated notes below give extra detail and test steps for individual changes:

- [`MOBILE_ACCESS_API.md`](MOBILE_ACCESS_API.md) — per-employee mobile access (`MOBILE_ACCESS_DISABLED`)
- [`MOBILE_API_UPDATE_2026-08.md`](MOBILE_API_UPDATE_2026-08.md) — single-device sessions (`SESSION_TERMINATED`), label empty state
- [`MOBILE_API_UPDATE_2026-09.md`](MOBILE_API_UPDATE_2026-09.md) — `onHand` on the product list
- [`MOBILE_API_DOCUMENT_UPLOAD.md`](MOBILE_API_DOCUMENT_UPLOAD.md) — attach scanned documents to records

What changed recently is listed in **§7**.

- **Base URL:** `{serverBaseUrl}/api/mobile/v1`
- **Auth:** Bearer JWT — header `Authorization: Bearer <accessToken>`
- **Content type:** `application/json` for all JSON bodies (image upload uses `multipart/form-data`)
- **All responses are JSON.** Errors use one envelope (see §3).

---

## 1. Authentication

JWT access token + rotating refresh token. The access token is short-lived; use `expiresIn`
(seconds, returned by login/refresh) to schedule refresh. Refresh tokens are **single-use**
(rotated on every refresh). Access-token claims: user id, name, roles, `companyId`, `scope`.

### POST `/auth/login`
```json
{ "username": "john", "password": "••••", "deviceId": "uuid-optional", "deviceName": "Samsung A54 (optional)" }
```
**200**
```json
{
  "accessToken": "eyJ…",
  "refreshToken": "…",
  "expiresIn": 3600,
  "scope": "read write",
  "user": { "id": "…", "name": "john", "roles": ["Sales"] },
  "session": {
    "displacedOtherDevice": false,
    "previousDeviceName": null,
    "previousLastSeenAt": null,
    "message": null            // non-null → show it: the account was open on another device, now signed out
  }
}
```
**One live session per account.** A new login signs out every other device; that device gets
`401 SESSION_TERMINATED` on its next call (§3). Refresh keeps the same session.

### POST `/auth/refresh`
```json
{ "refreshToken": "…" }
```
**200** → `{ "accessToken", "refreshToken", "expiresIn", "scope" }` (both tokens are new — store them).

### POST `/auth/logout`
```json
{ "refreshToken": "…" }
```
**204** No Content. (Revokes the refresh token. Also clear tokens locally.)

### GET `/auth/me`  *(auth required)*
**200** → `{ "id", "name", "email", "roles": [...], "scope": "read" | "read write" }`

---

## 2. Scopes

The `scope` claim controls write access to **product** edits:
- `read` — read-only everywhere; product-edit endpoints are still auth-gated by permission.
- `read write` — user may edit product barcode/model/price and manage product images.

Other write endpoints (sales, receipts, stock count) are gated by RBAC permissions on the user's role, not by `scope`.

---

## 3. Errors & access control

All errors share this envelope:
```json
{ "error": { "code": "SOME_CODE", "message": "Human-readable text." } }
```

| HTTP | code | Meaning / app action |
|---|---|---|
| 400 | `BAD_REQUEST` | Missing/invalid fields. Fix and retry. |
| 400 | `IDEMPOTENCY_KEY_REQUIRED` | A write was sent without the `Idempotency-Key` header (§4). |
| 401 | `UNAUTHENTICATED` | Bad credentials, or expired/invalid token → run the refresh flow; if refresh also 401, go to login. |
| 401 | `LOCKED_OUT` | Too many failed logins. Tell the user to wait. |
| 401 | `SESSION_TERMINATED` | The account signed in on another device. Show `error.message`, clear tokens, go to login. **Do not** refresh. |
| 403 | `FORBIDDEN` | The account/role isn't allowed the mobile app at all. |
| 403 | **`MOBILE_ACCESS_DISABLED`** | **NEW.** The user's mobile access is off (never granted, revoked, or seat reassigned). Can be returned by **login**, **refresh**, and **any** data endpoint. |

**`MOBILE_ACCESS_DISABLED` is the key change.** Mobile access is now granted **per employee** and
limited by the customer's **Mobile device licenses**. The server checks the user's access flag on
**every request**, so revoking access blocks the user on their **next call** — not at token expiry.

**Required app handling:** on any `403` with `code === "MOBILE_ACCESS_DISABLED"` →
clear tokens, show `error.message`, return to login, and **do not** run the refresh flow.
Full details + test steps: [`MOBILE_ACCESS_API.md`](MOBILE_ACCESS_API.md).

---

## 4. Conventions

- **Pagination:** list endpoints accept `?page=1&pageSize=25` (and usually `?search=`). Responses
  are paginated JSON (items + paging info).
- **Money/quantities:** decimals in the company base currency (BHD, 3 dp by default). VAT handling
  follows `pricesIncludeVat` on write requests.
- **Dates:** ISO-8601 (`2026-08-15` or full timestamp). Optional date fields default server-side.
- **`Idempotency-Key` header is required** on `POST /sales/cash-invoice/draft`, `/sales/cash-invoice`,
  `/sales/quotations`, `/inventory/stock-count` and `/receipts`. Send a fresh UUID per user action and
  **reuse the same key when retrying** that action: a repeat returns the first result instead of creating
  a second document. Missing → `400 IDEMPOTENCY_KEY_REQUIRED`.
- **Line price:** `price: null` on a line → resolved from the active price list.
- **Unit price is always excl. VAT in responses (1.6.51+).** Send `price` as the user typed it and set
  `pricesIncludeVat` to say which it is; the server stores the line's `unitPrice` **excluding VAT**
  at full precision (e.g. 1.400 incl. 10% → `1.272727…`). So `GET /sales/quotations/{id}` returns
  `lines[].unitPrice` excl. VAT even when `pricesIncludeVat` is true — round it for display, and use
  the line/header totals and `vatAmount` for money. Totals and VAT are unchanged by this.
- **Picture URLs are root-relative (1.6.52+)**, e.g. `/Files/Pictures/<guid>.jpg` — see §5a.

---

## 5. Endpoint reference

> All endpoints below require `Authorization: Bearer <accessToken>` and are subject to
> `MOBILE_ACCESS_DISABLED` (§3). `{id}` is an integer.

### App / catalog
| Method | Path | Purpose / params |
|---|---|---|
| GET | `/menu` | Menu/features the user may see |
| GET | `/products` | List. `?page&pageSize&search&categoryId&brandId` — `search` matches id, code, name, barcode, brand or category |
| GET | `/products/{id}` | One product |
| PATCH | `/products/{id}` | Edit product (scope `read write`) — body below |
| POST | `/products/{id}/images` | Upload images — `multipart/form-data`, field `images` (multiple); jpg/png/webp, ≤ 5 MB each |
| DELETE | `/products/{id}/images/{imageId}` | Remove a product image |
| GET | `/products/by-barcode/{code}` | Lookup by barcode |
| GET | `/categories` | Category list |
| GET | `/brands` | Brand list |
| GET | `/warehouses` | Warehouse list |
| GET | `/price-list/resolve?itemId=` | Resolved selling price for an item |

### 5a. Product pictures  🆕 (1.6.52)

Every picture comes with two links:

| Field | What it is | Use it for |
|---|---|---|
| `imageUrl` (list) / `images[].url` | The original upload (can be several MB) | Full-screen viewer, share, download |
| `thumbUrl` (list) / `images[].thumbUrl` | A 256 × 256 centre-cropped JPEG, cached on the server | List rows, photo strips |

```jsonc
// GET /products → items[]
{ "id": 1826, "code": "201384", "name": "…", "imageUrl": "/Files/Pictures/3f2c….jpg",
  "thumbUrl": "/Files/Thumb/3f2c….jpg?s=256", "onHand": 4 }

// GET /products/{id}, GET /products/by-barcode/{code}, POST /products/{id}/images → images[]
{ "id": 7, "url": "/Files/Pictures/3f2c….jpg", "thumbUrl": "/Files/Thumb/3f2c….jpg?s=256", "isPrimary": true }
```

- **Links are root-relative.** Join them to the origin of the API base URL the user signed in with
  (`https://erp.client.com/api/mobile/v1` → `https://erp.client.com` + link). Don't build your own host.
  A value that already starts with `http` is an external picture — use it as is.
- **`thumbUrl` can be `null`** (no picture, an external picture, or a server older than 1.6.52) → use the full `url`.
- Both picture endpoints are **anonymous** (file names are unguessable GUIDs); sending the Bearer header is harmless.
- `images[]` is ordered primary first. No picture → `imageUrl: null`, `images: []`.
- Servers before 1.6.52 sent absolute URLs whose host or scheme could be wrong for the phone. To support
  them, take the **path** of any absolute link that starts with `/Files/` and join it to your origin.

### Parties
| Method | Path | Purpose / params |
|---|---|---|
| GET | `/customers` | List. `?page&pageSize&search` |
| GET | `/customers/{id}/statement` | Customer statement |
| GET | `/customers/{id}/outstanding` | Open invoices / balance |
| GET | `/suppliers` | List. `?page&pageSize&search` |
| GET | `/suppliers/{id}/statement` | Supplier statement |

### Inventory
| Method | Path | Purpose / params |
|---|---|---|
| GET | `/inventory/stock-ledger` | `?itemId&warehouseId&page&pageSize` |
| GET | `/inventory/low-stock` | `?threshold&warehouseId&page&pageSize` |
| GET | `/inventory/dead-stock` | `?days&warehouseId&page&pageSize` |
| GET | `/inventory/stock-count/sheet` | Count sheet. `?warehouseId&search&page&pageSize` |
| POST | `/inventory/stock-count` | Submit a count — body below |

### Barcode labels  🆕 (v1.4.7)
Print barcode/QR labels from the item list. Templates are designed in the web app (Item Master →
Barcode/Label Designer). Gated by the **`MobileLabels`** permission (Mobile App group). The mobile
menu exposes this as **Print Labels** (`/labels`) when the permission is granted.

| Method | Path | Purpose / params |
|---|---|---|
| GET | `/label-templates` | Active templates → `{ version, count, hasLabels, message, templates:[{ id, name, widthMm, heightMm }] }` — `message` is non-null when no designs exist (show it as the empty state) |
| POST | `/labels/print` | Render a print-ready **PDF** (`application/pdf`). Body below. One label page per copy. |

`POST /labels/print` body:
```json
{ "templateId": 3, "items": [ { "itemId": 12, "quantity": 5 }, { "itemId": 40, "quantity": 2 } ] }
```
Response is the PDF binary (`Content-Type: application/pdf`); open/share/print it on the device.
Items with `quantity <= 0` are ignored; unknown items are skipped. Company scope comes from the token.

### Dashboard & reports
| Method | Path | Purpose / params |
|---|---|---|
| GET | `/dashboard/kpis` | `?from&to` |
| GET | `/reports/sales` | `?from&to` |
| GET | `/reports/purchase` | `?from&to` |

### Sales
| Method | Path | Purpose / params |
|---|---|---|
| GET | `/sales/tenders` | Payment tenders (cash/bank accounts) for cash sale |
| POST | `/sales/cash-invoice/draft` | Price a cart before posting — body below |
| POST | `/sales/cash-invoice` | Post a cash sale — body below |
| GET | `/sales/cash-invoice/{id}/receipt?format=` | Receipt (`format=pdf` for PDF) |
| GET | `/sales/quotations` | `?from&to&customerId&page&pageSize` |
| POST | `/sales/quotations` | Create quotation — body below |
| GET | `/sales/quotations/{id}` | One quotation |
| GET | `/sales/quotations/{id}/pdf` | Quotation PDF |

### Receipts
| Method | Path | Purpose |
|---|---|---|
| POST | `/receipts` | Record a customer receipt / allocation — body below |

### Documents (attach scans)
| Method | Path | Purpose |
|---|---|---|
| GET | `/documents/lookup` | Find a record by document number |
| POST | `/documents/attach` | Attach files — `multipart/form-data` |
| GET | `/documents/{docType}/{docId}/attachments` | Existing attachments |

Request/response details: [`MOBILE_API_DOCUMENT_UPLOAD.md`](MOBILE_API_DOCUMENT_UPLOAD.md).

---

## 5b. Manager reports  🆕 (v1.4.5)

Server-aggregated summaries — the app renders them directly and **never** pulls raw invoices to
compute totals. All are `GET`, all return `currency: "BHD"`, all are subject to
`MOBILE_ACCESS_DISABLED`. Two RBAC gates apply (grant per role in **User Roles → Mobile App**):

- **Reports** (`MobileReports`) — sales analytics: collections, sales trend, top items, by-category, by-salesman.
- **Finance Reports** (`MobileFinanceReports`) — sensitive money/profit/cost: AR aging, cash position, margin, VAT, inventory valuation.

A `403 FORBIDDEN` means the role lacks that gate. Date params are `YYYY-MM-DD`; `from`/`to` default to the current month.

### Tier 1 — cash-flow
**GET `/reports/receivables/aging?asOn=`**  · gate: Finance Reports
```json
{ "asOn":"2026-08-15","currency":"BHD","total":12500.000,
  "buckets":{"current":4000,"d30":3000,"d60":2500,"d90":2000,"d180plus":1000},
  "topDebtors":[{"customerId":12,"name":"Acme WLL","outstanding":3200.000,"oldestDays":91}] }
```
> Buckets are by invoice age since document date: `current`=1–30d, `d30`=31–60, `d60`=61–90, `d90`=91–180, `d180plus`=180+.

**GET `/reports/collections?from&to`**  · gate: Reports
```json
{ "from":"…","to":"…","currency":"BHD","total":8400.000,"count":37,
  "byMethod":[{"method":"Cash","amount":5000},{"method":"BankTransfer","amount":3400}],
  "byDay":[{"date":"2026-08-01","amount":1200}] }
```

**GET `/reports/cash-position?asOn=`**  · gate: Finance Reports
```json
{ "asOn":"2026-08-15","currency":"BHD",
  "accounts":[{"accountId":5,"name":"NBB Current","type":"Bank","balance":21000.000},
              {"accountId":9,"name":"Cash in Hand","type":"Cash","balance":850.000}],
  "totalCash":850.000,"totalBank":21000.000 }
```

### Tier 2 — performance & profit
**GET `/reports/sales/trend?from&to&groupBy=day|week|month`**  · gate: Reports
```json
{ "from":"…","to":"…","groupBy":"day","currency":"BHD",
  "points":[{"label":"2026-08-01","sales":1200.000,"invoices":6}],
  "total":36000.000,"avgPerDay":1200.000 }
```
> `week` labels are ISO weeks, e.g. `2026-W33`.

**GET `/reports/margin?from&to`**  · gate: Finance Reports
```json
{ "from":"…","to":"…","currency":"BHD","revenue":36000,"cost":24000,"grossProfit":12000,"marginPct":33.33,
  "byCategory":[{"name":"Sugar","revenue":12000,"margin":3000}] }
```

**GET `/reports/top-items?from&to&limit=10&by=value|qty`**  · gate: Reports
```json
{ "from":"…","to":"…","by":"value","currency":"BHD",
  "items":[{"itemId":101,"code":"SHB-SUG-1","name":"Sugar 1kg","qty":500,"value":610.000}] }
```

**GET `/reports/sales/by-category?from&to`**  · gate: Reports
```json
{ "from":"…","to":"…","currency":"BHD","categories":[{"name":"Sugar","sales":12000,"qty":9800}] }
```

### Tier 3 — compliance & operations
**GET `/reports/vat?from&to`**  · gate: Finance Reports — output (sales + cash + direct) vs input (purchase + direct)
```json
{ "from":"…","to":"…","currency":"BHD","outputVat":1800.000,"inputVat":1100.000,"netPayable":700.000 }
```

**GET `/reports/sales/by-salesman?from&to`**  · gate: Reports
```json
{ "from":"…","to":"…","currency":"BHD",
  "salesmen":[{"salesmanId":3,"name":"Ali Hassan","sales":15000,"invoices":42,"collections":9000}] }
```
> There is no salesman field on invoices — sales/collections are attributed via each **customer's assigned employee** (Employees → Assigned Customers). Customers with no assigned employee roll up under `salesmanId:0, "Unassigned"`.

**GET `/reports/inventory/valuation?warehouseId=`**  · gate: Finance Reports — stock value at weighted-average cost
```json
{ "asOn":"2026-08-15","currency":"BHD","totalValue":48000.000,"totalQty":9800,
  "byCategory":[{"name":"Sugar","value":12000,"qty":2000}],
  "byWarehouse":[{"name":"WH FACTORY","value":48000,"qty":9800}] }
```
> `warehouseId` is reserved; totals currently span all warehouses with a per-warehouse split in `byWarehouse`.

---

## 6. Write request bodies

**PATCH `/products/{id}`** — send only the fields to change; omitted/null fields are left as they are
```json
{ "barcode": "…?", "model": "…?", "defaultPrice": 12.500 }
```
**200** → `{ "id", "barcode", "model", "price" }`

**Sales line** (used in cash-invoice draft & quotations)
```json
{ "itemId": 101, "qty": 2, "price": null, "discount": 0, "discountType": "Percent",   // discountType: "Percent" | "Flat"
  "uomId": null, "vatCategoryId": null, "description": null }                          // null → item's unit / VAT category / name
```

**POST `/sales/cash-invoice/draft`**
```json
{
  "customerId": 0,               // 0 = walk-in
  "warehouseId": 1,
  "date": null,
  "pricesIncludeVat": false,
  "discount": 0,                 // invoice-level round-off off the net
  "lpoNumber": null, "reference": null, "notes": null,
  "lines": [ { "itemId": 101, "qty": 2, "price": null, "discount": 0, "discountType": "Percent" } ]
}
```

**POST `/sales/cash-invoice`**
```json
{
  "warehouseId": 1,
  "pricesIncludeVat": false,
  "discount": 0,
  "lines":   [ { "itemId": 101, "qty": 2, "price": null, "discount": 0, "uomId": null, "vatCategoryId": null } ],
  "payments":[ { "accountId": 5, "amount": 25.000, "reference": null } ]   // accountId from /sales/tenders
}
```

**POST `/sales/quotations`**
```json
{
  "customerId": 12,
  "date": null, "expiryDate": null,       // expiry null → date + 7 days
  "pricesIncludeVat": false,
  "discount": 0,
  "currencyCode": "BHD", "exchangeRate": 1,
  "paymentTerms": null, "reference": null, "notes": null,
  "lines": [ { "itemId": 101, "qty": 2, "price": null, "discount": 0, "discountType": "Percent" } ]
}
```

**POST `/inventory/stock-count`**
```json
{
  "warehouseId": 1,
  "notes": null,
  "lines": [ { "itemId": 101, "countedQty": 48 } ]
}
```

**POST `/receipts`**
```json
{
  "customerId": 12,
  "date": null,
  "accountId": 5,                 // cash/bank account receiving the money
  "paymentMethod": "Cash",        // Cash | BankTransfer | Cheque | PDC
  "reference": null,
  "amount": 100.000,
  "allocations": [ { "docType": "SalesInvoice", "docId": 340, "amount": 100.000 } ]
}
```

---

## 7. What changed (newest first)

| Version | Change | App action |
|---|---|---|
| **1.6.52** (Nov 2026) | Picture links are **root-relative**; new `thumbUrl` on every picture (§5a) | Join links to your API origin; show `thumbUrl` in lists, `url` full screen |
| **1.6.51** (Nov 2026) | Line `unitPrice` in responses is always **excl. VAT** (§4) | Don't treat `unitPrice` as inclusive on inclusive quotations; show money from the totals fields |
| 1.6.4x (Oct 2026) | `/products?search=` also matches id, brand and category | None |
| 1.6.25 (Sep 2026) | `onHand` on `/products` list and detail | Bind stock badges to `onHand` |
| Sep 2026 | Document attach endpoints (§5 Documents) | Optional feature |
| Aug 2026 | One live session per account: `session` on login, `401 SESSION_TERMINATED` (§1, §3); label-templates empty state | Handle `SESSION_TERMINATED` like `MOBILE_ACCESS_DISABLED` |
| 1.4.x | `403 MOBILE_ACCESS_DISABLED` (§3) | Clear tokens, show message, back to login, no refresh |

Corrections to earlier editions of this file: product edit is **`PATCH`** (it was shown as `PUT`); the
September note's "image URLs are now absolute" is superseded by 1.6.52 (relative).
