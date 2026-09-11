# LeoCore ERP — App Store Submission Pack

Bundle ID: `sek.leocore.erp` · Team: `QH862RRRJ6` · Version `2.6.0` build `8`
Target: iPhone only · Min iOS 15.0

---

## 1. App Information

| Field | Value |
|---|---|
| App Name (≤30) | `LeoCore ERP` |
| Subtitle (≤30) | `Inventory, Sales & Reports` |
| Primary Category | Business |
| Secondary Category | Productivity |
| Age Rating | 4+ |
| Price | Free |
| Primary Language | English (U.S.) |
| Also localized | Arabic (RTL supported in-app) |

## 2. URLs

| Field | Value |
|---|---|
| Privacy Policy URL | `https://leocoreerp.souqekamil.com/privacy-policy.html` |
| Support URL | `https://leocoreerp.souqekamil.com` |
| Marketing URL | (optional — leave blank) |

> Use **https://** — the site answers on HTTPS (verified). Do not enter the `http://`
> form that the current privacy-policy.html references.

## 3. Keywords (≤100 chars, no spaces after commas)

```
erp,inventory,barcode,stock,invoice,pos,sales,quotation,supplier,warehouse,scanner,business,bahrain
```

## 4. Promotional Text (≤170)

```
Run your business from your pocket — scan barcodes, raise invoices and quotations,
count stock, and see live sales, margin and aging reports.
```

## 5. Description

```
LeoCore ERP Mobile is the companion app for LeoCore ERP. Sign in to your company's
LeoCore server and manage inventory, sales and customers from anywhere — with the
same data, roles and permissions you already use on the desktop.

SCAN AND SELL
• Scan product barcodes with the camera to pull items up instantly
• Raise a cash sales invoice by scanning straight into the cart
• Create quotations and send them as a PDF
• Print barcode and shelf labels directly from your phone

INVENTORY IN YOUR HAND
• Full product catalogue with search, photos and live stock levels
• Stock counts with expected vs. counted quantities and variance
• Low stock and dead stock alerts so nothing goes unnoticed

CUSTOMERS AND SUPPLIERS
• Customer directory with a 360° view of activity
• Record receipts against outstanding invoices
• Account statements for both customers and suppliers

REPORTS THAT MATTER
• Sales and purchase reports with top-selling lists
• Business health: receivables aging, cash position, margin and trends
• Figures update live from your LeoCore server

BUILT FOR WORK
• English and Arabic, with full right-to-left layout
• Face ID / Touch ID unlock keeps business data private
• Light and dark themes
• Role-based access — users only see the modules they are entitled to

REQUIREMENTS
LeoCore ERP Mobile requires an active LeoCore ERP server and a user account issued
by your company's administrator. It is not a standalone product.
```

## 6. What's New in This Version

```
• Manager Reports — receivables aging, cash position, margin and trend analysis
• Print Labels — generate barcode and shelf labels from your phone
• Login now remembers the servers you use and offers them in a dropdown
• Clearer message when an administrator disables mobile access
• Stability and performance improvements
```

## 7. App Review Information  ← MOST IMPORTANT SECTION

The app is behind a login wall. **Apple will reject it without working credentials.**

| Field | Value |
|---|---|
| Sign-in required | YES |
| Demo Server URL | `https://leocoredemo.seksolution.com` (pre-filled by the app) |
| Username | `mic` |
| Password | `mic@159357` |

**Notes for Reviewer** (paste into the Notes field):

```
LeoCore ERP Mobile is a B2B companion app for LeoCore ERP, an on-premise/hosted
business management system used by retail and wholesale companies. It is not a
standalone app — it requires a LeoCore ERP server.

HOW TO SIGN IN
1. Launch the app. The first screen asks for a "Server location".
2. It is already pre-filled with https://leocoredemo.seksolution.com
3. Username: mic    Password: mic@159357
4. Tap Sign in. The demo account has all modules enabled.

ACCOUNTS
User accounts are provisioned by the customer's own ERP administrator inside the
LeoCore ERP back office. The app cannot register accounts and does not offer
account creation, so guideline 5.1.1(v) account deletion does not apply — an
administrator removes users from the server.

CAMERA
The camera is used only to scan product barcodes and to attach a product photo.
On the Simulator the scanner cannot open a camera; please test on a device.

FACE ID
Face ID is an optional convenience lock for re-entry and can be disabled in Settings.
```

## 8. Privacy — Nutrition Labels

No analytics, advertising or tracking SDKs are present (verified against pubspec).
Tokens and settings live only in the iOS Keychain on-device.

**App Privacy answers:**

- *Do you or your third-party partners collect data from this app?* → **Yes**
  (business data is sent to the customer's own LeoCore server)
- *Used for tracking?* → **No, across the board**

| Data Type | Collected | Linked to user | Tracking | Purpose |
|---|---|---|---|---|
| Contact Info — Name | Yes | Yes | No | App Functionality |
| Identifiers — User ID | Yes | Yes | No | App Functionality |
| Other Data (business/inventory records) | Yes | Yes | No | App Functionality |
| Photos | Yes | Yes | No | App Functionality |
| Usage Data / Diagnostics | No | — | — | — |
| Location | No | — | — | — |

## 9. Screenshots — REQUIRED

Only one size is mandatory:

- **6.9" iPhone — 1290 × 2796 px** (portrait), 3 to 10 images, no alpha channel.

The existing `screenshot_*.png` files are **1080 × 1920 (Android)** and will be
rejected. They must be replaced.

Captured and ready in `store_assets/ios_screenshots_6.9/` (1320×2868, no alpha):
1. `01_dashboard.png`      — dashboard: AR 809,629 BHD, low-stock, workspace grid
2. `02_products.png`       — product catalogue with category filters and prices
3. `03_product_detail.png` — barcode, VAT class, cost price, Add-to-memo / Count
4. `04_customers.png`      — customer directory with balances and ageing badges
5. `05_customer_360.png`   — outstanding balance, ageing bars, call/WhatsApp/navigate
6. `06_print_labels.png`   — Print Labels with template selected, 22 labels queued

NOT used: Reports and Manager Reports (Business health) render empty because the
demo dataset has no recent sales. See section 9b for demo-account module access.

## 9b. Demo-account module access (verified 2026-08-18)

The app hides modules the server does not grant. `AppState` derives each gate
from `/api/mobile/v1/menu`, so what a reviewer sees depends entirely on the
`mic` account's permissions. Measured against the live demo server:

| Gate | Demo user `mic` |
|---|---|
| Suppliers, Reports, Business health, Stock count, Cash sale | VISIBLE |
| Print Labels (`mLabels`) | VISIBLE — granted 2026-08-18 |

Print Labels was originally permission-gated off for `mic` — `/label-templates`
returned 403 and the menu omitted it, so the row did not render in More at all.
That was correct app behaviour, not a bug: calling `openLabels()` directly (as a
screenshot harness can) bypasses the gate and surfaces a toast a real user would
never see. Both the permission and a template have since been added.

RESOLVED 2026-08-18: `mic` was granted the **Barcode Labels** permission and a
template was created (`id 1, "Barcode", 50x30mm`). Verified end to end —
`/label-templates` returns the template, and `POST /labels/print` returns a
valid `application/pdf` (22 KB, 2 pages). Screenshot 06 shows it working.

Re-verify any time with:

```
TOK=$(curl -sS -X POST https://leocoredemo.seksolution.com/api/mobile/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"mic","password":"mic@159357","deviceName":"diag"}' \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['accessToken'])")

curl -sS -H "Authorization: Bearer $TOK" \
  https://leocoredemo.seksolution.com/api/mobile/v1/label-templates
```
Expect HTTP 200 and a template list, and a label entry in `/menu`.

**Reports / Business health render empty**: the demo company has no sales in the
last 7/30 days, so those screens show zeros and "No activity in this period".
Not a rejection risk, but seeding recent demo sales would make review — and any
sales demo — look considerably better.

## 10. Export Compliance

Already answered in `Info.plist` via `ITSAppUsesNonExemptEncryption = false`
(standard HTTPS only). App Store Connect will not prompt on upload.

---

## Pre-flight checklist

- [x] Bundle ID `sek.leocore.erp`, team set
- [x] Privacy usage strings for camera, photo library, Face ID
- [x] Export compliance declared
- [x] App icon 1024×1024, no alpha
- [x] Launch image replaced (was a 1×1 placeholder)
- [x] Target narrowed to iPhone only
- [x] Release archive builds clean (180 MB — was 202 MB before the ML Kit removal)
- [x] `mobile_scanner` 5.2.3 → 7.4.0 (iOS backend swapped from Google ML Kit to Apple Vision)
- [x] Login footer version un-hardcoded (showed a stale v2.4.1, now reads the bundle)
- [x] **Apple Distribution certificate** — created (Souq E Kamil Trading and Solutions WLL, QH862RRRJ6)
- [x] **App Store provisioning profile** — 'iOS Team Store Provisioning Profile: sek.leocore.erp'
- [x] **Signed App Store IPA built** — `store_assets/LeoCoreERP-2.6.0-b7-appstore.ipa` (21 MB)
- [x] **App record created in App Store Connect**
- [x] **Build 7 uploaded** — 2026-08-18, delivery UUID e2ddd1dd-1752-457c-aa9e-fb8a7441b741
- [x] **6.9" screenshots** — 5 captured from the live demo server at 1320×2868, alpha stripped, in `store_assets/ios_screenshots_6.9/`
- [x] **Demo account for review** — mic / mic@159357

---

# Appendix A — Signing setup (do this in Xcode, once)

You currently have only an **Apple Development** certificate. Uploading needs an
**Apple Distribution** certificate plus an **App Store** provisioning profile.
Xcode creates both automatically once the account is connected.

### A1. Confirm the account is in Xcode
1. Open **Xcode → Settings → Accounts**
2. Confirm `info@seksolution.com` is listed. If not, click **+ → Apple ID** and sign in.
3. Select the account. In the right pane confirm the team whose ID is **QH862RRRJ6**.
4. Your role must be **Account Holder** or **Admin** — a Developer-role user
   cannot create distribution certificates.

### A2. Let Xcode create the distribution certificate
```
open /Users/hussaindeen/Documents/LeoCoreMobile/leocore_mobile/ios/Runner.xcworkspace
```
1. Select the **Runner** target → **Signing & Capabilities** tab
2. Tick **Automatically manage signing**
3. Set **Team** to the QH862RRRJ6 team
4. Switch the tab's config selector to **Release**
5. Xcode provisions the certificate + profile and the yellow warning clears

Verify from the terminal — you should now see an "Apple Distribution" line:
```
security find-identity -v -p codesigning
```

### A3. Create the app record in App Store Connect
1. Go to https://appstoreconnect.apple.com → **My Apps → +  → New App**
2. Platform **iOS**, Name **LeoCore ERP**, Primary Language **English (U.S.)**
3. Bundle ID: pick **sek.leocore.erp**
   - If it is not in the list, register it first at
     https://developer.apple.com/account/resources/identifiers
4. SKU: `LEOCORE-ERP-IOS` (any internal string)
5. User Access: Full Access

### A4. Build and upload  (VERIFIED WORKING 2026-08-18)

Auth uses an App Store Connect API key, **not** an app-specific password.
`altool --store-password-in-keychain-item` is BROKEN in Xcode 26 — it writes the
item with a NULL service attribute and then cannot read its own item back. Do not
use it. The API key path below works.

Credentials already installed:
```
Key file    ~/.appstoreconnect/private_keys/AuthKey_R86H46956N.p8   (chmod 600)
Key ID      R86H46956N
Issuer ID   afc4f68b-4d8f-4940-ad87-fbd53041cc13
```

Full release sequence:
```
cd /Users/hussaindeen/Documents/LeoCoreMobile/leocore_mobile
# bump `version:` in pubspec.yaml first — build number must increase every upload

flutter build ipa --release --export-method app-store

xcrun altool --validate-app -f build/ios/ipa/*.ipa -t ios \
  --apiKey R86H46956N --apiIssuer afc4f68b-4d8f-4940-ad87-fbd53041cc13

xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios \
  --apiKey R86H46956N --apiIssuer afc4f68b-4d8f-4940-ad87-fbd53041cc13
```

### A4b. The build number in the IPA is NOT the one in pubspec.yaml

Flutter generates `ExportOptions.plist` with `manageAppVersionAndBuildNumber = true`.
On export, Xcode queries App Store Connect, finds the highest build already
uploaded, and stamps the IPA with **that number + 1** — whatever `pubspec.yaml`
says. Verified 2026-08-19:

| Artifact | CFBundleVersion |
|---|---|
| `pubspec.yaml` | 8 |
| `Runner.xcarchive` | 8 |
| `build/ios/iphoneos/Runner.app` (device build) | 8 |
| **exported `LeoCore ERP.ipa`** | **9** (8 was the highest on ASC) |

Consequences:

- You cannot accidentally upload a duplicate build number. Convenient.
- The number shown in App Store Connect may not match `pubspec.yaml`. Read the
  IPA, not the pubspec, when you need to know what you actually shipped:
  ```
  unzip -p "build/ios/ipa/LeoCore ERP.ipa" "Payload/Runner.app/Info.plist" \
    | plutil -p - | grep CFBundleVersion
  ```
- Still bump `pubspec.yaml` for each release — it drives
  `CFBundleShortVersionString` (the user-visible version) and the Android
  `versionCode`, neither of which is auto-managed.

### A5. After upload
- The build takes 10–30 minutes to finish processing before it can be selected.
- Attach it to the version, fill in the metadata from sections 1–8 above,
  add the demo credentials in section 7, then **Add for Review**.

---

# Review status log

**2026-08-18** — build 8 uploaded, version submitted, status `WAITING_FOR_REVIEW`.

**2026-08-19** — **Rejected**, Guideline 2.1 *Information Needed — New App
Submission* (shown as `2.1.0 Performance: App Completeness`).

Not a defect. Apple's standard first-submission questionnaire: they want seven
questions answered in App Review Information → Notes, plus a screen recording
captured on a physical device. Re-verified the same day that the demo login and
both URLs still respond, so the credentials were never the problem.

The paste-ready reply, the recording shot list and the Notes-field text are in
**`APPLE_2.1_REPLY.md`**. No new build was required — build 8 stood throughout.

**2026-09-01** — replied with a 1:53 screen recording captured on a physical
iPhone 16 Pro Max (iOS 26.5.2), showing a cold launch, the full sign-in, the
camera permission alert at 00:46, a live barcode scan, populated reports, label
printing to PDF, Arabic RTL and dark theme. Sent text: `apple_reply_4000.txt`
(the reply box caps at 4000 characters, so the long form in `APPLE_2.1_REPLY.md`
does not fit). App Review Information → Notes: `apple_review_notes.txt`.
Resubmitted, `WAITING_FOR_REVIEW`.

**2026-09-04** — **Rejected again**, Guideline 3.2 *Business* — Apple judged the
app to be built for a specific organisation rather than a public audience, and
suggested Custom App or Unlisted distribution instead.

Root cause was our own listing. The **Support URL pointed at
`leocoreerp.souqekamil.com`, an unconfigured parked domain** serving the hosting
provider's placeholder page. A reviewer checking whether LeoCore ERP is a real,
openly available product found a domain-reseller ad. The description's
REQUIREMENTS paragraph ("an account issued by your company's administrator...
not a standalone product") and the phrasing of our own 2.1 reply ("the audience
is those companies' own staff, not the general public") reinforced it.

Fixes applied, in this order — the URL first, so the reply's claim was already
true when Apple checked it:

1. Support URL and Marketing URL → `https://leocoreerp.seksolution.com`, the
   real product site, which carries a "Book a 30-min walkthrough" CTA.
2. Description REQUIREMENTS rewritten — `apple_description_requirements.txt`.
3. Replied with `apple_reply_3.2.txt`, answering Apple's five questions: five
   separate unaffiliated customer companies, open to any business that buys a
   licence, accounts issued by each customer's own administrator for security
   (not as a restriction on who may become a customer), no in-app purchases,
   and the same app already publicly listed on Google Play.

**2026-09-05** — **APPROVED and live.** `READY_FOR_SALE` /
`READY_FOR_DISTRIBUTION`, submission `COMPLETE`.

## If a 3.2 challenge ever recurs

The deciding question is whether *any* company can become a customer, not how
many currently are. Keep the Support URL pointing at a real product page with
public pricing or a demo request — that single link is what a reviewer uses to
test the claim. If Apple rejects twice on 3.2, take **Unlisted App
Distribution** rather than arguing a third time: the app keeps a permanent
direct link for customers and simply does not appear in search.

---

# Appendix B — iCloud broke iOS code signing (found and FIXED 2026-08-19)

**RESOLVED.** iCloud Desktop & Documents sync has been turned off and the stale
attributes stripped. Release builds now work from the repo in place. Kept here
because the failure is cryptic and costs an hour if it recurs.

**Symptom.** Any `flutter build ios` / `flutter build ipa` / Xcode archive fails:

```
Failed to codesign .../Flutter.framework/Flutter with identity <hash>.
  .../Flutter.framework/Flutter: replacing existing signature
  .../Flutter.framework/Flutter: resource fork, Finder information, or similar
  detritus not allowed
```

**Cause.** The repo lives in `~/Documents` and iCloud Drive was syncing that
folder. iCloud stamps `com.apple.FinderInfo` (plus `com.apple.fileprovider.fpfs#P`)
onto the directories it manages, and `codesign` refuses to sign anything
carrying it.

**Two red herrings, so nobody chases them again:**

- `com.apple.provenance` is on every file and looks like the obvious suspect.
  It is not the cause — a copy carrying only provenance signs fine. The
  offending attribute is `com.apple.FinderInfo`, and it sits on the *directory*,
  not the binary.
- `xattr -cr build/` appears to work but does not, *while sync is still on*.
  iCloud re-applies the attribute faster than the delete pass runs — one
  measured attempt went from 26 stamped paths to 42 *during* the strip.

**The fix that was applied** (in this order — the second step is not optional,
turning sync off does not clean up what is already stamped):

1. System Settings → Apple Account → iCloud → iCloud Drive →
   **Desktop & Documents Folders** → off. Confirm with:
   ```
   defaults read com.apple.finder FXICloudDriveDocuments   # want 0
   defaults read com.apple.finder FXICloudDriveDesktop     # want 0
   ```
2. Strip the ~66 attributes iCloud left behind:
   ```
   cd ~/Documents/LeoCoreMobile
   rm -rf leocore_mobile/build
   find . -xattrname com.apple.FinderInfo \
     -exec xattr -d com.apple.FinderInfo {} \; 2>/dev/null
   find . -xattrname 'com.apple.fileprovider.fpfs#P' \
     -exec xattr -d 'com.apple.fileprovider.fpfs#P' {} \; 2>/dev/null
   ```

**Verified 2026-08-19 after the fix:** `flutter build ios --release` and
`flutter build ipa --release --export-method app-store` both succeed from the
repo in place, and a full build leaves `find . -xattrname com.apple.FinderInfo`
at **0**.

**If it ever comes back**, check that count first — that one command tells you
whether this is the problem. The emergency workaround is to build from a copy
outside any synced folder (`flutter build` has no `--build-dir` flag):

```
DEST=/tmp/leocore_build
rsync -a --delete --exclude build/ --exclude .dart_tool/ --exclude ios/Pods/ \
  --exclude ios/.symlinks/ --exclude .git/ --exclude android/.gradle/ \
  ~/Documents/LeoCoreMobile/leocore_mobile/ "$DEST/"
cd "$DEST" && flutter pub get && flutter build ipa --release --export-method app-store
```

## Appendix C — installing on a device for a review recording

Registered devices (`GET /v1/devices`):

| Device | UDID | Status |
|---|---|---|
| HUSSAIN's iPhone (iPhone 12 Pro, iOS 18.7.8) | `00008101-00051DE60152001E` | ENABLED |
| Jamila iPhone 16 Pro Max, iOS 26.5.2 | `00008140-00161D140013C01C` | ENABLED |

After registering a new device, Xcode keeps using its **cached** profile and the
build silently omits the device. Clear the cache and rebuild:

```
mv ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/*.mobileprovision /tmp/backup/
cd /tmp/leocore_build && rm -rf build/ios/iphoneos && flutter build ios --release

# confirm the device is in the profile before installing
security cms -D -i build/ios/iphoneos/Runner.app/embedded.mobileprovision | \
  python3 -c "import sys,plistlib;p=plistlib.loads(sys.stdin.buffer.read());print(len(p['ProvisionedDevices']))"

xcrun devicectl device install app --device <UDID> build/ios/iphoneos/Runner.app
xcrun devicectl device process launch --device <UDID> sek.leocore.erp
```

The device also needs **Developer Mode** on (Settings → Privacy & Security →
Developer Mode), which only appears in Settings after a Mac has connected once.

## Appendix D — App Store Connect API without altool

`xcrun altool --generate-jwt` does not work in Xcode 26. Sign the ES256 JWT
directly instead — `openssl` plus a DER→raw signature conversion is enough, and
needs no third-party Python packages. Working script:
`store_assets/asc_jwt.py`.
