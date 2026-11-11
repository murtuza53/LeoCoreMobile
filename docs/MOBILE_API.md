# LeoCore Mobile API — Reference (v1)

For the mobile app team. **Current as of LeoCore ERP 1.6.54 (10 Nov 2026).** This one file is the complete
reference: it replaces the separate notes (`MOBILE_ACCESS_API.md`, `MOBILE_API_UPDATE_2026-08.md`,
`MOBILE_API_UPDATE_2026-09.md`, `MOBILE_API_DOCUMENT_UPLOAD.md`), whose content is merged in below.

- **Base URL:** `{serverBaseUrl}/api/mobile/v1` (e.g. `https://erp.client.com/api/mobile/v1`)
- **Auth:** Bearer JWT — header `Authorization: Bearer <accessToken>`
- **Content type:** `application/json` for JSON bodies; uploads use `multipart/form-data`
- **All responses are JSON** except files/PDFs. Errors use one envelope (§3).
- **No `companyId` parameter anywhere** — company scope comes from the token.

## Contents

1. [Authentication & sessions](#1-authentication--sessions)
2. [Scopes & permissions](#2-scopes--permissions)
3. [Errors & access control](#3-errors--access-control)
4. [Conventions](#4-conventions)
5. [Endpoint reference](#5-endpoint-reference)
6. [Products & pictures](#6-products--pictures)
7. [Barcode labels](#7-barcode-labels)
8. [Attach Docs (document attachments)](#8-attach-docs-document-attachments)
9. [Manager reports](#9-manager-reports)
10. [Write request bodies](#10-write-request-bodies)
11. [App checklist & tests](#11-app-checklist--tests)
12. [What changed (newest first)](#12-what-changed-newest-first)

---

## 1. Authentication & sessions

JWT access token + rotating refresh token. The access token is short-lived; use `expiresIn`
(seconds, returned by login/refresh) to schedule refresh. Refresh tokens are **single-use**
(rotated on every refresh). Access-token claims: user id, name, roles, `companyId`, `scope`, and an
internal `sid` (session id) that the app never reads or sends.

### POST `/auth/login`
```json
{ "username": "jsmith", "password": "••••", "deviceId": "a1b2c3-stable-per-install", "deviceName": "John's iPhone 15" }
```
- **`deviceId`** — a **stable per-install identifier**, so a re-login from the same phone is not reported
  as "another device".
- **`deviceName`** — human-friendly; it is shown to the user in the displacement message.

**200**
```json
{
  "accessToken": "eyJ…",
  "refreshToken": "…",
  "expiresIn": 1800,
  "scope": "read write",
  "user": { "id": "…", "name": "jsmith", "roles": ["Sales"] },
  "session": {
    "displacedOtherDevice": true,
    "previousDeviceName": "John's iPad",
    "previousLastSeenAt": "2026-08-18T18:12:03Z",
    "message": "This account was already signed in on \"John's iPad\". That device has been signed out automatically."
  }
}
```
When the account was not signed in elsewhere, `session` is
`{ "displacedOtherDevice": false, "previousDeviceName": null, "previousLastSeenAt": null, "message": null }`.
**If `session.message` is non-null, show it** (toast/alert).

Login can fail with `401 UNAUTHENTICATED`, `401 LOCKED_OUT` or `403 MOBILE_ACCESS_DISABLED` (§3).

### POST `/auth/refresh`
```json
{ "refreshToken": "…" }
```
**200** → `{ "accessToken", "refreshToken", "expiresIn", "scope" }` (both tokens are new — store them).
A refresh keeps the **same** session alive; only a new **login** signs other devices out.

| Refresh result | Meaning | App action |
|---|---|---|
| `200` | New pair | Save **both** tokens before using them |
| `401 SESSION_TERMINATED` | The account signed in on another device (message names it) | Hard sign-out, show message |
| `401 UNAUTHENTICATED` | Token unknown, expired, or logged out | Go to login |
| `403 MOBILE_ACCESS_DISABLED` / `FORBIDDEN` | Access revoked | Hard sign-out, show message |
| `429 RATE_LIMITED`, `5xx`, no network | **Not** a verdict on the token | Keep the session; retry later |

- **Lost reply protection (1.6.52):** a refresh token that was rotated in the last **2 minutes** is accepted once
  more while its session is live — so if the phone never received the reply (dropped connection, app killed),
  retrying with the old token still works instead of signing the user out.
- **Admins (1.6.52 fix):** the built-in `admin` user and the Admin/SuperAdmin roles skip the mobile permission
  and seat checks on login, refresh **and** every call. (Before 1.6.52 refresh did not, so admins were signed out
  with `MOBILE_ACCESS_DISABLED` at their first token renewal — about every 30 minutes.)
- Refresh only when a call returns `401 UNAUTHENTICATED` (or on app open/resume); share **one** in-flight refresh
  between parallel calls.

### POST `/auth/logout`
```json
{ "refreshToken": "…" }
```
**204** No Content. Revokes the refresh token; also clear tokens locally.

### GET `/auth/me`
**200** → `{ "id", "name", "email", "roles": [...], "scope": "read" | "read write" }`

### 1a. One live session per account

- Each account holds **one active session**. When the user logs in on device **B**, device **A** is signed
  out on its **very next API call** (not only when its token expires).
- Device A then gets **`401 SESSION_TERMINATED`** on any endpoint. Treat it as a hard sign-out: clear tokens,
  go to login, show `error.message`. **Do not refresh** — the old refresh token returns `401 UNAUTHENTICATED`.

```
HTTP/1.1 401 Unauthorized
{ "error": { "code": "SESSION_TERMINATED",
             "message": "You have been signed out because your account was signed in on another device." } }
```

---

## 2. Scopes & permissions

**Scope** (`scope` claim) controls write access to **product** edits:
- `read` — read-only; product edit/image endpoints refuse.
- `read write` — may edit product barcode/model/price and manage product images.

**Permissions (RBAC).** Everything else is gated by the user's role permissions. On the web, **Administration →
User Roles → Permissions** has a **Mobile App** tab: one row per mobile page, with the rights View / Create / Edit /
Delete / Print / Email, and under each row a note of which buttons each right turns on. Mobile rights are separate
from the web rights. Admin/SuperAdmin always have every permission.

**The rule for the app:** a page appears (menu, Home tile, More list, bottom bar) only when its feature has **View**;
each button appears only when its feature has the right in the table. The server enforces the same rules on every
call (`403 FORBIDDEN`), so hiding is about not offering what would be refused.

| Feature key | Permission-page row | Menu id | View | Other rights → buttons |
|---|---|---|---|---|
| `MobileAccess` | Mobile App (Access) | — | may sign in at all | — |
| `MobileDashboard` | Dashboard & KPIs | `dashboard` | Home KPI cards and sales trend | — |
| `MobileProducts` | Products | `products` | Products list/detail, **Scan** button | **Edit** = "Edit barcode / price", add / remove photos |
| `MobileLabels` | Barcode Labels | `labels` | Print Labels screen | **Print** = Print button |
| `MobileCustomers` | Customers | `customers` | Customers tab, customer detail | — |
| `MobileSuppliers` | Suppliers | `suppliers` | Suppliers list | — |
| `MobileStatements` | Statements & Ledgers | `statements` | Statements tile; statement card on a customer; tapping a supplier | — (download/share/print come with View) |
| `MobileStockLedger` | Stock Ledger | `stock-ledger` | stock movements, warehouse list | — |
| `MobileStockAlerts` | Stock Alerts (Low / Dead Stock) | `stock-alerts` | Low stock tile, Stock alerts, the Low-stock KPI tap | — |
| `MobileReports` | Reports | `reports` | Reports; sales analytics in Business Health | — |
| `MobileFinanceReports` | Finance Reports | `finance-reports` | finance cards in Business Health (§9) | — |
| `MobileCashSales` | Cash Sales | `cash-sale` | — | **Create** = Cash Sale screen and "Add to memo" (product, scan); **Print** = sale PDF |
| `MobileQuotations` | Quotations | `quotations` | Saved quotations | **Create** = new quotation; **Print** = Download / Share PDF |
| `MobileStockCount` | Stock Counting | `stock-count` | Stock count sheet | **Create** = Submit count, "Count" (product, scan) |
| `MobileReceipts` | Receipts | `receipts` | customer outstanding invoices | **Create** = record a receipt (no screen yet) |
| `MobileDocuments` | Document Attachments | `documents` | Attach Docs, open files | **Edit** = attach; **Delete** = delete an attachment (also per document as `canAttach` / `canDelete`, §8) |

**1.6.54:** `MobileStockAlerts` is new. Low / dead stock used to need `MobileStockLedger`; on upgrade every role
gets Stock Alerts with the same View it had on Stock Ledger, so nobody loses the page.

### GET `/menu` (version 2)
Returns the pages the user has View on, each with its rights, plus `permissions` — the rights for **every** Mobile
App feature (including ones that aren't pages, such as `MobileAccess`). Rights are only ever `true` when the
feature offers them (e.g. Products never reports `create`) and View is on.
```json
{
  "version": 2,
  "items": [
    { "id": "cash-sale", "title": "Cash Sale", "icon": "point_of_sale", "route": "/cash-sale",
      "section": "Transactions", "order": 80, "feature": "MobileCashSales", "canEdit": false,
      "rights": { "view": true, "create": true, "edit": false, "delete": false, "print": true, "email": false } }
  ],
  "permissions": {
    "MobileAccess":    { "view": true,  "create": false, "edit": false, "delete": false, "print": false, "email": false },
    "MobileProducts":  { "view": true,  "create": false, "edit": true,  "delete": false, "print": false, "email": false },
    "MobileStockAlerts": { "view": false, "create": false, "edit": false, "delete": false, "print": false, "email": false }
  }
}
```
- Gate by **feature key** from `permissions`, not by matching titles or ids.
- `canEdit` is kept for app builds that read menu v1. A v1 server has no `permissions`; treat each listed item as
  View + Create + Print, Edit from `canEdit`.
- **Refresh the menu** after sign-in and when the app returns to the foreground (at most once a minute), so a
  change on the permission page reaches the phone without signing out. If the page on screen is no longer
  allowed, go Home.
- **Read the menu first, then load only what the pages need.** At sign-in, call `/menu` before anything else and
  fetch products / customers / KPIs / warehouses only when a permitted page uses them. A role with only Attach
  Docs must make no product, customer or KPI calls.
- **Never show a page before its rights are known.** Save the last `permissions` on the phone (cleared on
  sign-out) and use that copy when `/menu` can't be reached. If there is no copy either, show an error with
  Retry — never "everything" (that showed every page empty to limited roles). `403` on `/menu` (no Mobile
  Access) = no pages.
- Home and More show only pages with View, from the one permission set. With full access they are unchanged:
  Home tiles Products, Customers, Suppliers, Cash Sale, Stock Count, Low Stock, Reports, Statements, Settings;
  More rows Cash sales invoice, Quotation, Saved quotations, Stock count, Stock alerts, Reports, Business
  health, Print Labels, Attach Docs, Suppliers, Settings. A role with none of the Home tiles gets its pages as
  Home tiles instead (documents only → Attach Docs), and a role with no Dashboard and exactly one page can open
  straight on that page.
- The Home **sales chart** reads `/reports/sales`, which needs **Reports**: with Dashboard but no Reports, show
  the KPI cards without the chart (not "No sales").
- Item search in Cash Sale / Quotation uses `/products`, which needs **Products** View. A role with Quotations
  or Cash Sales but without Products can open those screens but can't add items — give such roles Products
  View for now.
- A `403` on a list is final: show "You don't have access", and **do not request it again** on the next
  rebuild/refresh of the screen (only pull-to-refresh retries). Re-requesting on every build loops and flickers.

A missing permission on an endpoint → `403 FORBIDDEN`.

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
| 401 | `SESSION_TERMINATED` | Signed in on another device (§1a). Clear tokens, show message, go to login. **No refresh.** |
| 403 | `FORBIDDEN` | The role lacks the permission for this endpoint (§2). |
| 403 | `MOBILE_ACCESS_DISABLED` | The user's mobile access is off (§3a). Clear tokens, show message, go to login. **No refresh.** |
| 404 | `NOT_FOUND` | The record doesn't exist (or was deleted). |
| 409 | `STORAGE_NOT_CONFIGURED` | File storage is not set up on the server (attachments). |
| 429 | `RATE_LIMITED` | Too many calls from this phone (300/min for data, 20/min per IP for login/refresh). Wait (`Retry-After: 60`) and retry — **never** sign out. |

### 3a. Per-employee mobile access — `MOBILE_ACCESS_DISABLED`

Mobile access is granted **per employee** and limited by the customer's **mobile device licences**. An admin
can switch a user's access off at any time, or reassign the seat. The server checks the access flag on
**every request**, so revoking blocks the user on their **next call**, not at token expiry.

```json
{ "error": { "code": "MOBILE_ACCESS_DISABLED",
             "message": "Your mobile access has been disabled. Please contact your administrator." } }
```

| Returned by | When |
|---|---|
| `POST /auth/login` | Access is off → login refused |
| `POST /auth/refresh` | Access was turned off since the last token (the refresh token is revoked too) |
| **any** data endpoint | Access was turned off while the user was signed in |

The seat limit is enforced by the server; the app doesn't track seats.

### 3b. HTTP layer (interceptor)

```
onResponse(res):
    code = res.body?.error?.code
    if res.status == 403 and code == "MOBILE_ACCESS_DISABLED"
       or res.status == 401 and code == "SESSION_TERMINATED":
        clearTokens(); showMessage(res.body.error.message); navigateToLogin()
        return                      // hard sign-out — do NOT refresh
    if res.status == 401:           // UNAUTHENTICATED
        refresh once and retry; if refresh fails → login
```

---

## 4. Conventions

- **Pagination:** list endpoints accept `?page=1&pageSize=50` (max **200**) and return
  `{ page, pageSize, total, hasMore, items:[…] }`. **Load the next page while `hasMore` is true** (infinite
  scroll) — never assume one page is the whole list.
- **Search is on the server.** Send what the user types as `?search=` (debounce ~300 ms, reset to page 1) and
  show the server's result — don't filter only the rows already on screen, which misses everything not yet loaded.
- **Money/quantities:** decimals in the company base currency (BHD, 3 dp by default). VAT handling
  follows `pricesIncludeVat` on write requests.
- **Dates:** ISO-8601 (`2026-08-15` or a full timestamp). Timestamps ending in `Z` are UTC — show them in local time.
- **`Idempotency-Key` header is required** on `POST /sales/cash-invoice/draft`, `/sales/cash-invoice`,
  `/sales/quotations`, `/inventory/stock-count` and `/receipts`. Send a fresh UUID per user action and
  **reuse the same key when retrying** that action: a repeat returns the first result instead of creating
  a second document. Missing → `400 IDEMPOTENCY_KEY_REQUIRED`.
- **Line price:** `price: null` on a line → resolved from the active price list.
- **Unit price is always excl. VAT in responses (1.6.51+).** Send `price` as the user typed it and set
  `pricesIncludeVat` to say which it is; the server stores the line's `unitPrice` **excluding VAT**
  at full precision (e.g. 1.400 incl. 10% → `1.272727…`). So `GET /sales/quotations/{id}` returns
  `lines[].unitPrice` excl. VAT even when `pricesIncludeVat` is true — round it for display, and use
  the line/header totals and `vatAmount` for money.
- **Links are root-relative (1.6.52+).** Picture and attachment links look like `/Files/…` or
  `/api/mobile/v1/…`. Join them to the **origin** of the API base URL the user signed in with
  (`https://erp.client.com/api/mobile/v1` → `https://erp.client.com` + link) — not to the API path.
  Standard URI resolution does this: `resolve("https://host/api/mobile/v1/x", "/Files/Pictures/a.jpg")`.
  A value that already starts with `http` is used as is.

---

## 5. Endpoint reference

> All endpoints require `Authorization: Bearer <accessToken>` (except the two picture files, §6) and can
> return `MOBILE_ACCESS_DISABLED` / `SESSION_TERMINATED` (§3). `{id}` is an integer.

### App / catalog
| Method | Path | Purpose / params |
|---|---|---|
| GET | `/menu` | Pages the user may see, with rights per page and a `permissions` map (version 2, §2) |
| GET | `/products` | List. `?page&pageSize&search&categoryId&brandId` — `search` matches id, code, name, barcode, brand or category (§6) |
| GET | `/products/{id}` | One product (§6) |
| PATCH | `/products/{id}` | Edit product (scope `read write`) — §10 |
| POST | `/products/{id}/images` | Upload images (§6) |
| DELETE | `/products/{id}/images/{imageId}` | Remove a product image |
| GET | `/products/by-barcode/{code}` | Lookup by barcode |
| GET | `/categories` | Category list |
| GET | `/brands` | Brand list |
| GET | `/warehouses` | Warehouse list |
| GET | `/price-list/resolve?itemId=` | Resolved selling price for an item |

### Parties
| Method | Path | Purpose / params |
|---|---|---|
| GET | `/customers` | List. `?page&pageSize&search&balance&sort` — see below |
| GET | `/customers/{id}/statement` | Customer statement |
| GET | `/customers/{id}/outstanding` | Open invoices / balance |
| GET | `/suppliers` | List. `?page&pageSize&search&balance&sort` — see below |
| GET | `/suppliers/{id}/statement` | Supplier statement |

**Customer / supplier lists** (also feed the Statements picker):
- `search` — name, email, phone, VAT/TRN number or id.
- `balance=nonzero` — only parties with an outstanding balance ("hide zero balances" switch).
- `sort=name` (default) or `sort=balance` (largest outstanding first).
- Each item: `{ id, name, email, phone, country, currency, outstanding, creditLimit (customers) }`. `outstanding`
  (BHD, 3 dp) is what the customer owes us / what we owe the supplier — the same figure as the statement.
  **Suppliers have `outstanding` from 1.6.52.**
  `outstanding` comes from the AR/AP aging and is reused for up to **60 seconds** per company (the same figures the
  web Customers / Suppliers lists show), so paging and search stay fast with thousands of parties; a receipt just
  posted can take up to a minute to show in the list. The statement itself is always live.
```json
{ "page": 1, "pageSize": 50, "total": 119, "hasMore": true, "currency": "BHD",
  "items": [ { "id": 12, "name": "ROOPAM TEXTILE", "email": null, "phone": "17000000", "country": "Bahrain",
               "currency": "BHD", "creditLimit": 0, "outstanding": 8843.930 } ] }
```

### Inventory
| Method | Path | Purpose / params |
|---|---|---|
| GET | `/inventory/stock-ledger` | `?itemId&warehouseId&page&pageSize` |
| GET | `/inventory/low-stock` | `?threshold&warehouseId&page&pageSize` — `MobileStockAlerts` |
| GET | `/inventory/dead-stock` | `?days&warehouseId&page&pageSize` — `MobileStockAlerts` |
| GET | `/inventory/stock-count/sheet` | Count sheet. `?warehouseId&search&page&pageSize` |
| POST | `/inventory/stock-count` | Submit a count — §10 |

### Barcode labels (§7)
| Method | Path | Purpose |
|---|---|---|
| GET | `/label-templates` | Label designs the user may print |
| POST | `/labels/print` | Render a print-ready PDF |

### Dashboard & reports
| Method | Path | Purpose / params |
|---|---|---|
| GET | `/dashboard/kpis` | `?from&to` |
| GET | `/reports/sales` | `?from&to` |
| GET | `/reports/purchase` | `?from&to` |
| GET | `/reports/…` | Manager reports — §9 |

### Sales
| Method | Path | Purpose / params |
|---|---|---|
| GET | `/sales/tenders` | Payment tenders (cash/bank accounts) for cash sale |
| POST | `/sales/cash-invoice/draft` | Price a cart before posting — §10 |
| POST | `/sales/cash-invoice` | Post a cash sale — §10 |
| GET | `/sales/cash-invoice/{id}/receipt?format=` | Receipt (`format=pdf` for PDF) |
| GET | `/sales/quotations` | `?from&to&customerId&search&page&pageSize` — `search` matches number, customer or reference |
| POST | `/sales/quotations` | Create quotation — §10 |
| GET | `/sales/quotations/{id}` | One quotation |
| GET | `/sales/quotations/{id}/pdf` | Quotation PDF |

### Receipts
| Method | Path | Purpose |
|---|---|---|
| POST | `/receipts` | Record a customer receipt / allocation — §10 |

### Attach Docs (§8)
| Method | Path | Purpose | `MobileDocuments` access |
|---|---|---|---|
| GET | `/documents/lookup?number=` | Find a document **and its existing attachments** | View |
| POST | `/documents/attach` | Attach one or more files (multipart) | Edit |
| GET | `/documents/{docType}/{docId}/attachments` | Re-load the attachment list | View |
| GET | `/documents/attachments/{id}/file` | Open a file; `?download=true` to download | View |
| DELETE | `/documents/attachments/{id}` | Delete an attachment (record **and** file) | Delete |

---

## 6. Products & pictures

### GET `/products?page=1&pageSize=25&search=&categoryId=&brandId=`
```jsonc
{
  "page": 1, "pageSize": 25, "total": 137,
  "items": [
    {
      "id": 10104,
      "code": "10104",
      "name": "Shubbakh Sugar 1kg",
      "barcode": "6291000000000",
      "price": 0.220,                                  // DefaultPrice, base currency
      "cost": 0.200,                                   // DefaultCost
      "brand": "Shubbakh",                             // string | null
      "category": "Sugar",                             // string | null
      "imageUrl": "/Files/Pictures/3f2c….jpg",         // primary picture, full size | null
      "thumbUrl": "/Files/Thumb/3f2c….jpg?s=256",      // 256 px thumbnail | null
      "onHand": 134.000                                // stock, base unit, all warehouses (may be 0 or negative)
    }
  ]
}
```

### GET `/products/{id}` and GET `/products/by-barcode/{code}`
```jsonc
{
  "id": 10104, "code": "10104", "name": "Shubbakh Sugar 1kg", "barcode": "6291000000000",
  "model": null, "type": "Stock", "price": 0.220, "cost": 0.200,
  "brand": "Shubbakh", "category": "Sugar", "uom": "Ea",
  "onHand": 134.000,
  "canEdit": true,
  "images": [
    { "id": 55, "url": "/Files/Pictures/3f2c….jpg", "thumbUrl": "/Files/Thumb/3f2c….jpg?s=256", "isPrimary": true }
  ]
}
```
`onHand` is a decimal in the item's **base unit**, summed across **all warehouses**, from the stock ledger.
Treat `<= 0` as out of stock.

### POST `/products/{id}/images`
`multipart/form-data`, field **`images`** (repeatable). Types `.jpg .jpeg .png .webp`, ≤ 5 MB each.
Scope `read write`. → `{ "images": [ {id, url, thumbUrl, isPrimary} ] }`.

### Pictures

| Field | What it is | Use it for |
|---|---|---|
| `imageUrl` (list) / `images[].url` | The original upload (can be several MB) | Full-screen viewer, share, download |
| `thumbUrl` (list) / `images[].thumbUrl` | A 256 × 256 centre-cropped JPEG, cached on the server | List rows, photo strips |

- Links are **root-relative** — join to the API origin (§4).
- **`thumbUrl` can be `null`** (no picture, an external picture, or a server older than 1.6.52) → use `url`.
- Both picture endpoints (`/Files/Pictures/…`, `/Files/Thumb/…`) are **anonymous** (file names are
  unguessable GUIDs); sending the Bearer header is harmless.
- `images[]` is ordered primary first. No picture → `imageUrl: null`, `images: []`.
- **Servers before 1.6.52** sent absolute URLs whose host or scheme could be wrong for the phone. To
  support them, take the **path** of any absolute link that starts with `/Files/` and join it to your origin.

---

## 7. Barcode labels

Print barcode/QR labels from the item list. Designs are made in the web app (Barcode/Label Designer).
Permission **`MobileLabels`**; the menu item is **Print Labels** (`/labels`).

### GET `/label-templates`
```json
{
  "version": 1, "count": 2, "hasLabels": true, "message": null,
  "templates": [
    { "id": 1, "name": "Shelf label 50×30", "widthMm": 50, "heightMm": 30 },
    { "id": 4, "name": "Barcode 40×20",     "widthMm": 40, "heightMm": 20 }
  ]
}
```
When no designs exist: `count: 0`, `hasLabels: false`, `templates: []` and `message` =
"No label designs have been created yet. Add one in the web app under Barcode Labels, then it will appear here."
→ `hasLabels: true` shows the picker; `false` shows `message` as the empty state.

### POST `/labels/print`
```json
{ "templateId": 1, "items": [ { "itemId": 12, "quantity": 3 }, { "itemId": 34, "quantity": 1 } ] }
```
- `200` → `application/pdf` (one label per copy) — open/share/print it on the device.
- Items with `quantity <= 0` are ignored; unknown items are skipped.
- `400 BAD_REQUEST` (missing template/items, no valid quantities) · `404 NOT_FOUND` (template not found).

---

## 8. Attach Docs (document attachments)

Look up any document by its number, see the files already attached (open, share, delete a wrong one),
and attach more scans/photos — the phone version of the web **DropBox** and per-document **Attachments**
panel. Same store, so files attached from the phone show on the web and vice versa.
Permission **`MobileDocuments`**: View (look up/list/open), Edit (attach), Delete (delete) — §2.
Menu item `documents` → `/documents`.

### 8.0 The attachment object

Every endpoint returns attachments in this one shape, **newest first**:
```json
{
  "id": 191,
  "fileName": "JV-2026-0035_a9860bfd.png",
  "size": 81234,
  "contentType": "image/png",
  "isImage": true,
  "isPdf": false,
  "uploadedAt": "2026-11-09T19:10:33.277Z",
  "uploadedBy": "admin",
  "url": "/api/mobile/v1/documents/attachments/191/file",
  "downloadUrl": "/api/mobile/v1/documents/attachments/191/file?download=true"
}
```
- `fileName` is the stored name: `<document number>_<8 random chars><ext>` (the phone's filename is not kept).
- `uploadedAt` is UTC; `uploadedBy` can be `null` on very old attachments.
- `url`/`downloadUrl` are root-relative (§4) and — unlike pictures — **need the Bearer header**
  (business documents are not public). Load them with an authenticated HTTP client / image loader.
- `isImage` / `isPdf` pick the viewer (image viewer, PDF viewer, else share sheet / "Open with").

### 8.1 GET `/documents/lookup?number=<documentNumber>`

Exact match across all document types (sales & purchase quotations, orders, invoices, returns, delivery
notes, GRNs, purchase inquiries, journal vouchers). A file extension on `number` is ignored
(`INV-2026-0001.pdf` works).

**Found — 200**
```json
{
  "found": true,
  "docType": "JournalEntry",
  "docId": 3361,
  "docNumber": "JV-2026-0035",
  "docTypeLabel": "Journal / Voucher",
  "canAttach": true,
  "canDelete": false,
  "attachmentCount": 2,
  "attachments": [ { …attachment… }, { …attachment… } ]
}
```
`attachments` is `[]` when nothing is attached. Use `canAttach` / `canDelete` to show or hide the buttons.

**Not found — 200** (not an error): `{ "found": false, "number": "INV-2026-9999" }`
Errors: `400 BAD_REQUEST` (empty number) · `403 FORBIDDEN`.

### 8.2 POST `/documents/attach`  (`multipart/form-data`)

| field | type | notes |
|---|---|---|
| `number` | text | the document number (use `docNumber` from the lookup) |
| `files` | file (repeatable) | one or more files — one `files` part per file |

Max request 60 MB; each file is checked (type + size). The server re-matches `number`, so the app can only
attach to a real document.

**200**
```json
{
  "success": true,
  "docType": "JournalEntry", "docId": 3361, "docNumber": "JV-2026-0035",
  "attached": 2,
  "files": [
    { "id": 191, "fileName": "JV-2026-0035_a9860bfd.png", "originalName": "scan1.png", "size": 81234 },
    { "id": 192, "fileName": "JV-2026-0035_00b4607e.pdf", "originalName": "note.pdf",  "size": 23111 }
  ],
  "errors": [],
  "attachments": [ …the full list after the upload… ]
}
```
Redraw from `attachments` — no second call needed. Rejected files are listed in `errors`
(`[ { "originalName": "huge.mov", "message": "File exceeds the maximum allowed size." } ]`).

| status | code | meaning |
|---|---|---|
| 400 | `BAD_REQUEST` | missing `number` or no files |
| 400 | `UPLOAD_FAILED` | every file was rejected |
| 404 | `NOT_FOUND` | no document has that number |
| 409 | `STORAGE_NOT_CONFIGURED` | file storage is not set up on the server |
| 403 | `FORBIDDEN` | no Edit |

**No idempotency key here:** each call stores new files, so a retried upload creates duplicates. Don't
auto-retry after a timeout — re-run the lookup and check the list first.

### 8.3 GET `/documents/{docType}/{docId}/attachments`
→ `{ "docType", "docId", "attachments": [ … ] }`. Use for pull-to-refresh.

### 8.4 GET `/documents/attachments/{id}/file[?download=true]`
Returns the raw file with its `Content-Type`; `Content-Disposition: inline` (or `attachment` with
`download=true`) and `Cache-Control: private, no-store` (a temp file for viewing/sharing is fine).
Errors come back as JSON — check the status before treating the body as a file:

| status | code | meaning |
|---|---|---|
| 403 | `FORBIDDEN` | no View |
| 404 | `NOT_FOUND` | attachment deleted (by someone else) — reload the list |
| 404 | `FILE_MISSING` | the record exists but the file is gone from the server — show the message; the user can delete the entry |

### 8.5 DELETE `/documents/attachments/{id}`
Deletes the record **and** the stored file — gone for the web too, cannot be undone, recorded in the
Audit Log. **Always ask the user to confirm** (show the name/thumbnail).
**200** → `{ "success": true, "id": 191, "docType": "JournalEntry", "docId": 3361, "attachments": [ …what is left… ] }`
Errors: `403 FORBIDDEN` (no Delete) · `404 NOT_FOUND` (already deleted — reload).

### 8.6 Suggested screen
1. User types or scans the document number → **8.1**.
   `found:false` → "Document not found". `found:true` → header `docTypeLabel` · `docNumber`, then
   **"Attached (n)"**: image thumbnails (load `url` with Bearer), file icons for PDFs/others; each row shows
   name, size, local time and `uploadedBy`. Empty → "Nothing attached yet".
2. Tap → full-screen viewer (zoom for images, PDF viewer) with **Share** and **Download**.
3. Delete icon/swipe (only when `canDelete`) → confirm → **8.5** → redraw from `attachments`.
4. **Add** (only when `canAttach`) → camera scan or pick files → **8.2** → redraw; show `attached` and any `errors`.

**Servers before 1.6.52:** a found lookup has no `attachments` key, and the file/delete endpoints return
404 — detect the missing key and hide view/delete.

---

## 9. Manager reports

Server-aggregated summaries — the app renders them directly and **never** pulls raw invoices to compute
totals. All `GET`, all return `currency: "BHD"`. Two gates (§2):
- **Reports** (`MobileReports`) — collections, sales trend, top items, by category, by salesman.
- **Finance Reports** (`MobileFinanceReports`) — AR aging, cash position, margin, VAT, inventory valuation.

Date params are `YYYY-MM-DD`; `from`/`to` default to the current month.

### Cash flow
**GET `/reports/receivables/aging?asOn=`**  · Finance Reports
```json
{ "asOn":"2026-08-15","currency":"BHD","total":12500.000,
  "buckets":{"current":4000,"d30":3000,"d60":2500,"d90":2000,"d180plus":1000},
  "topDebtors":[{"customerId":12,"name":"Acme WLL","outstanding":3200.000,"oldestDays":91}] }
```
> Buckets by invoice age since document date: `current`=1–30d, `d30`=31–60, `d60`=61–90, `d90`=91–180, `d180plus`=180+.

**GET `/reports/collections?from&to`**  · Reports
```json
{ "from":"…","to":"…","currency":"BHD","total":8400.000,"count":37,
  "byMethod":[{"method":"Cash","amount":5000},{"method":"BankTransfer","amount":3400}],
  "byDay":[{"date":"2026-08-01","amount":1200}] }
```

**GET `/reports/cash-position?asOn=`**  · Finance Reports
```json
{ "asOn":"2026-08-15","currency":"BHD",
  "accounts":[{"accountId":5,"name":"NBB Current","type":"Bank","balance":21000.000},
              {"accountId":9,"name":"Cash in Hand","type":"Cash","balance":850.000}],
  "totalCash":850.000,"totalBank":21000.000 }
```

### Performance & profit
**GET `/reports/sales/trend?from&to&groupBy=day|week|month`**  · Reports
```json
{ "from":"…","to":"…","groupBy":"day","currency":"BHD",
  "points":[{"label":"2026-08-01","sales":1200.000,"invoices":6}],
  "total":36000.000,"avgPerDay":1200.000 }
```
> `week` labels are ISO weeks, e.g. `2026-W33`.

**GET `/reports/margin?from&to`**  · Finance Reports
```json
{ "from":"…","to":"…","currency":"BHD","revenue":36000,"cost":24000,"grossProfit":12000,"marginPct":33.33,
  "byCategory":[{"name":"Sugar","revenue":12000,"margin":3000}] }
```

**GET `/reports/top-items?from&to&limit=10&by=value|qty`**  · Reports
```json
{ "from":"…","to":"…","by":"value","currency":"BHD",
  "items":[{"itemId":101,"code":"SHB-SUG-1","name":"Sugar 1kg","qty":500,"value":610.000}] }
```

**GET `/reports/sales/by-category?from&to`**  · Reports
```json
{ "from":"…","to":"…","currency":"BHD","categories":[{"name":"Sugar","sales":12000,"qty":9800}] }
```

### Compliance & operations
**GET `/reports/vat?from&to`**  · Finance Reports — output (sales + cash + direct) vs input (purchase + direct)
```json
{ "from":"…","to":"…","currency":"BHD","outputVat":1800.000,"inputVat":1100.000,"netPayable":700.000 }
```

**GET `/reports/sales/by-salesman?from&to`**  · Reports
```json
{ "from":"…","to":"…","currency":"BHD",
  "salesmen":[{"salesmanId":3,"name":"Ali Hassan","sales":15000,"invoices":42,"collections":9000}] }
```
> Attributed via each **customer's assigned employee**; customers with none roll up under `salesmanId:0, "Unassigned"`.

**GET `/reports/inventory/valuation?warehouseId=`**  · Finance Reports — stock value at weighted-average cost
```json
{ "asOn":"2026-08-15","currency":"BHD","totalValue":48000.000,"totalQty":9800,
  "byCategory":[{"name":"Sugar","value":12000,"qty":2000}],
  "byWarehouse":[{"name":"WH FACTORY","value":48000,"qty":9800}] }
```
> `warehouseId` is reserved; totals span all warehouses with a split in `byWarehouse`.

---

## 10. Write request bodies

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

**POST `/sales/cash-invoice/draft`**  (Idempotency-Key required)
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

**POST `/sales/cash-invoice`**  (Idempotency-Key required)
```json
{
  "warehouseId": 1,
  "pricesIncludeVat": false,
  "discount": 0,
  "lines":   [ { "itemId": 101, "qty": 2, "price": null, "discount": 0, "uomId": null, "vatCategoryId": null } ],
  "payments":[ { "accountId": 5, "amount": 25.000, "reference": null } ]   // accountId from /sales/tenders
}
```

**POST `/sales/quotations`**  (Idempotency-Key required)
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

**POST `/inventory/stock-count`**  (Idempotency-Key required)
```json
{ "warehouseId": 1, "notes": null, "lines": [ { "itemId": 101, "countedQty": 48 } ] }
```

**POST `/receipts`**  (Idempotency-Key required)
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

## 11. App checklist & tests

**Checklist**
- [ ] Send a stable `deviceId` + friendly `deviceName` on login; show `session.message` when non-null.
- [ ] Interceptor (§3b): `403 MOBILE_ACCESS_DISABLED` and `401 SESSION_TERMINATED` → hard sign-out, no refresh;
      other `401` → refresh once.
- [ ] Build navigation from `GET /menu` v2 and hide every button whose right is off (§2 table); refresh the
      menu on sign-in and on return to the foreground.
- [ ] Load `/menu` first; load other data only for permitted pages; keep a saved copy of the rights for
      offline; never fall back to "show everything" (§2).
- [ ] A refused (`403`) list shows "no access" once and is not re-requested by rebuilds.
- [ ] Every list (products, customers, suppliers, statements picker, quotations, stock count, low/dead stock):
      server `search`, infinite scroll on `hasMore`; customers/suppliers/statements get a "hide zero balances"
      switch (`balance=nonzero`) and a sort by balance.
- [ ] Treat `429 RATE_LIMITED`, `5xx` and timeouts as "try again", never as sign-out.
- [ ] Report rows (names with bars): show the full name (wrap to 2 lines, or name on its own line above the bar).
- [ ] Send `Idempotency-Key` on the five writes in §4 and reuse it on retry.
- [ ] Join every root-relative link to the API origin (§4).
- [ ] Product lists show `thumbUrl`; viewer uses `url`; stock badge from `onHand`.
- [ ] Label screen: picker when `hasLabels`, else `message`.
- [ ] Attach Docs: show attachments after lookup; open with Bearer; delete with confirmation; hide buttons by `canAttach`/`canDelete`.

**Tests**
1. *Mobile access:* admin turns Mobile Access off while the app is open → next call returns
   `403 MOBILE_ACCESS_DISABLED` → app shows the message and returns to login; login is refused; re-enable → login works.
2. *Single device:* sign in on phone A, then on phone B → B shows "already signed in on …"; A's next call
   returns `401 SESSION_TERMINATED` → A returns to login.
3. *Pictures:* a product with pictures shows thumbnails in the list and the full picture in the viewer.
4. *Attach Docs:* look up a number with files → list shows them; open an image and a PDF; attach a scan →
   list updates; delete it (with Delete permission) → list updates; without Delete the button is hidden.
5. *Mobile permissions:* give a role only Mobile Access, Dashboard, Customers and Statements → the app shows
   Home KPIs, the Customers tab and Statements, with no Products tab, no Scan button and no Cash Sale / Quotation /
   Count; turn on Quotations View only → "Saved quotations" appears without "Quotation" (new) or the PDF buttons;
   untick Stock Alerts while the app is open, switch away and back → the Low stock tile disappears.
6. *Limited role (document scanning):* a role with only Mobile Access + Attach Docs → after sign-in the app opens
   on Attach Docs; More lists Attach Docs and Settings only; no Products/Customers tabs, no Scan button, no KPI
   cards; the server log shows no `/products`, `/customers` or `/dashboard/kpis` calls from that user. Sign in
   offline afterwards → the same pages appear (saved rights).

---

## 12. What changed (newest first)

| Version | Change | App action |
|---|---|---|
| **1.6.54** (Nov 2026) | **Limited roles & big lists:** app rules for roles with few pages (menu first, saved rights, no "show everything", `403` lists not re-requested, sales chart only with Reports; item search needs Products); customer / supplier `outstanding` reused for 60 s so paging and search are fast with thousands of parties (§2, §5) | Load the menu first and only permitted data; stop re-requesting refused lists; keep the full-access Home/More unchanged; chart only with Reports |
| **1.6.54** (Nov 2026) | **Mobile permissions:** the role permission page has a **Mobile App** tab; `GET /menu` is **version 2** with `feature` + `rights` per page and a `permissions` map for every Mobile App feature; new menu pages `stock-alerts`, `finance-reports`, `quotations`; new feature **`MobileStockAlerts`** gates `/inventory/low-stock` and `/inventory/dead-stock` (carried over from Stock Ledger on upgrade) (§2) | Gate pages and buttons by feature rights; refresh the menu on resume |
| **1.6.52** (Nov 2026) | **Sign-out fixes:** admins no longer refused on refresh (`MOBILE_ACCESS_DISABLED` every ~30 min); a refresh whose reply was lost is accepted again for 2 min; a refresh after a login elsewhere returns `SESSION_TERMINATED` naming the device; new token issued before the old is revoked; rate limits are per phone, and 429 uses the error envelope (`RATE_LIMITED`) (§1, §3) | Treat 429/5xx as retry, not sign-out |
| **1.6.52** (Nov 2026) | Lists: `hasMore` on every paged list; `pageSize` up to 200; customers/suppliers `balance=nonzero`, `sort=balance`, search by phone/VAT/TRN/id; suppliers gain `outstanding`; quotations `search` (§4, §5) | Infinite scroll + server search everywhere; zero-balance filter |
| **1.6.52** (Nov 2026) | Attach Docs: lookup returns the existing `attachments` + `canAttach`/`canDelete`; new open-file and **delete** endpoints; new **Delete** access on `MobileDocuments`; attachment `url` now opens through the API; added `isImage`, `isPdf`, `downloadUrl`; `uploadedAt` marked UTC (§8) | Show the files after lookup; open with Bearer; delete with confirmation |
| **1.6.52** (Nov 2026) | Picture links are **root-relative**; new `thumbUrl` on every picture (§6) | Join links to your API origin; `thumbUrl` in lists, `url` full screen |
| **1.6.51** (Nov 2026) | Line `unitPrice` in responses is always **excl. VAT** (§4) | Don't treat `unitPrice` as inclusive; show money from the totals |
| 1.6.4x (Oct 2026) | `/products?search=` also matches id, brand and category | None |
| 1.6.25 (Sep 2026) | `onHand` on `/products` list and detail; `/Files/Pictures` made anonymous; `.webp`/`.gif` content types fixed | Bind stock badges to `onHand` |
| Sep 2026 | Attach Docs: lookup, attach, list | Optional feature |
| Aug 2026 | One live session per account: `session` on login, `401 SESSION_TERMINATED` (§1a); label-templates `count`/`hasLabels`/`message` (§7) | Hard sign-out on `SESSION_TERMINATED`; label empty state |
| 1.4.x | Per-employee access: `403 MOBILE_ACCESS_DISABLED` (§3a) | Hard sign-out, no refresh |

Corrections to earlier editions: product edit is **`PATCH`** (it was shown as `PUT`); the September note's
"image URLs are absolute" is replaced by root-relative links (1.6.52). This file now includes the content of
the former separate notes, which have been removed.
