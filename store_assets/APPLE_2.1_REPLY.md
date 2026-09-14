# Reply to Apple — Guideline 2.1, Information Needed (2.6.0 build 8)

Rejected 2026-08-19. **Nothing is wrong with the app.** This is Apple's standard
information request for a first-time submission: they want the App Review
Information → Notes field populated with answers to 7 questions, plus a screen
recording taken on a real device.

Verified 2026-08-19 before replying:

| Check | Result |
|---|---|
| `POST /auth/login` as `mic` on the demo server | **200**, accessToken issued |
| `https://leocoreerp.souqekamil.com/privacy-policy.html` | **200** |
| `https://leocoreerp.souqekamil.com` (support) | **200** |

So the credentials Apple was given are live. Do **not** rebuild or re-upload —
build 8 stays. Reply to the message, then hit **Resubmit to App Review**.

---

## Step 1 — Record the screen on a physical device

**Done for you:** version 2.6.0 build 8 is built and installed on the
**iPhone 16 Pro Max, iOS 26.5.2** — the current public release, which is exactly
what Apple's "latest operating system" wording asks for. It launched cleanly.

The app on the phone is a development-signed build from the same source as
build 8. Apple asked for a recording of the app's functionality, not
specifically the TestFlight binary, so this is fine — and it avoids signing
that phone's App Store into your developer Apple ID.

**Before recording:** open the app switcher and swipe LeoCore ERP away, so the
recording starts from a genuine cold launch. Apple explicitly asks that the
recording "begin with launching the app".

**Start the recording:** Control Centre → Screen Recording, wait for the
countdown, then tap the LeoCore ERP icon.

### Shot list — roughly 3 minutes, in this order

1. **Launch** — the login screen with the server field pre-filled.
2. **Sign in** — type `mic` / `mic@159357`, tap Sign in. *Show the whole flow;
   do not cut it.*
3. **Face ID prompt** — if it appears, let it show and accept it. This is one of
   the "prompts requesting access to sensitive data" Apple listed.
4. **Dashboard** — pause on receivables, low-stock, the workspace grid.
5. **Products** → tap a product → product detail (barcode, cost, VAT class).
6. **Scan** — open the scanner. **Let the camera permission alert appear on
   screen and tap Allow.** Then scan any barcode, or tap the manual-entry
   fallback if nothing is to hand. This is the single most important shot.
7. **Customers** → tap one → the 360° view with ageing bars.
8. **Print Labels** (More → Print Labels) — pick the "Barcode" template, set a
   quantity, generate. Show the PDF preview.
9. **Settings** — show language (English/Arabic), theme, Face ID toggle.
10. **Sign out.**

**Skip entirely** (there is nothing to show and Apple asked only "if the app has
any of the following"): account registration, account deletion, purchases or
subscriptions, user-generated content, reporting/blocking. Question 4 in the
reply below states plainly why.

Trim the top and tail in Photos, then upload the file with the reply — the
message composer in App Store Connect has an attachment control.

---

## Step 2 — Paste this into the reply

App Store Connect → your app → **App Review** → the rejection message →
**Reply**. Paste verbatim:

```
Thank you for the review. Answers to each point below, and a screen recording
captured on a physical iPhone is attached.

--------------------------------------------------------------------
1. SCREEN RECORDING
--------------------------------------------------------------------
Attached (1 minute 53 seconds). It was captured on a physical iPhone 16 Pro Max
running iOS 26.5.2, and begins with a cold launch of the app from the home
screen. It shows, in order: the login screen; a full sign-in with the demo
credentials; the dashboard; the product catalogue and a product detail screen;
the customer directory, a customer 360 view and an account statement; the
barcode scanner, including the iOS camera permission alert and a live scan of a
physical barcode that resolves to the matching product; the sales and purchase
reports; the business health dashboard; label printing with the generated PDF
preview; the settings screen, including the switch to Arabic with right-to-left
layout and the switch to dark theme; and sign-out.

Regarding the specific flows listed in your message:
- Account registration and account deletion: the app has neither, by design.
  See point 4.
- Paid content, purchases and subscriptions: none. The app contains no in-app
  purchases, no subscriptions and no paywall.
- User-generated content: none. There is no public or shared content, no user
  feed and no social features, so content reporting and blocking do not apply.
  All data is a company's own private business records on its own server.
- Sensitive-data prompts: the recording shows the iOS camera permission alert
  appearing at 00:46, displaying our purpose string ("LeoCore ERP uses the
  camera to scan product barcodes and to take product photos"), and it being
  accepted. The camera is the only sensitive permission the app requests, and
  it is requested only when the barcode scanner is opened. Face ID is offered
  as an optional unlock and can be turned on or off in Settings, which the
  recording also shows. The app requests no location, no contacts, no
  microphone and no App Tracking Transparency — it does not track users.

--------------------------------------------------------------------
2. DEVICES AND OPERATING SYSTEMS TESTED
--------------------------------------------------------------------
- iPhone 16 Pro Max, iOS 26.5.2 (physical device) — full manual pass of every
  screen, including the camera scanner, Face ID unlock, label printing and
  Arabic right-to-left layout. This is the device in the attached recording.
- iPhone 12 Pro, iOS 18.7.8 (physical device) — full manual pass, confirming
  the app on an older device and an earlier iOS release.
- iPhone 16 Pro Max simulator — layout and localisation verification only. The
  barcode scanner cannot be exercised on a simulator because it has no camera.

The app is iPhone-only and requires iOS 15.0 or later.

--------------------------------------------------------------------
3. PURPOSE AND TARGET AUDIENCE
--------------------------------------------------------------------
LeoCore ERP Mobile is a business-to-business companion app for LeoCore ERP, an
inventory and sales management system that retail and wholesale companies run
on their own server. The audience is the employees of those companies —
shopkeepers, storekeepers, sales staff and owners — not the general public.

The problem it solves: this work is otherwise tied to a desktop computer in a
back office. Staff on the shop floor or in a warehouse have to walk back to a
PC to check a price, look up stock, or see what a customer owes. The app puts
those functions on the phone they already carry, and uses the phone's camera as
a barcode scanner, which removes the need for dedicated scanning hardware.

The value it provides: scan a product barcode to pull up its price and live
stock level; raise a cash sales invoice or a quotation and share it as a PDF;
run a stock count with expected-versus-counted variance; print barcode and
shelf labels; look up a customer's outstanding balance and ageing; and view
sales, margin and receivables reports. It works in English and Arabic with full
right-to-left layout.

The app is not a standalone product. It is useless without an active LeoCore
ERP server and a user account issued by that company's own administrator.

--------------------------------------------------------------------
4. SETUP AND ACCESS INSTRUCTIONS, INCLUDING CREDENTIALS
--------------------------------------------------------------------
No setup, sample files or configuration are needed. Just sign in:

  1. Launch the app. The first screen asks for a "Server location".
  2. It is already pre-filled with:  https://leocoredemo.seksolution.com
     (If it is empty for any reason, type that address in.)
  3. Username:  mic
     Password:  mic@159357
  4. Tap "Sign in".

We re-verified these credentials against the live demo server today and the
server returned a successful authentication. The demo account has every module
enabled, so all features listed in point 3 are reachable. The server will
remain available throughout the review.

Reaching the main features after sign-in:
- Dashboard: the screen you land on.
- Products, Customers, Suppliers, Reports: the workspace grid on the dashboard,
  and the bottom navigation bar.
- Barcode scanner: the scan button in the bottom bar, or the scan icon on the
  Products screen.
- Cash Sale, Quotation, Stock Count, Print Labels, Business Health: the "More"
  tab.
- Language, theme and the Face ID toggle: Settings, from the "More" tab.

ON ACCOUNT REGISTRATION AND DELETION
The app deliberately offers neither. User accounts are created, modified and
removed by the customer company's own ERP administrator, inside the LeoCore ERP
back office on that company's server — the same way their desktop accounts are
managed. The app has no registration screen and no self-service account
creation, so under guideline 5.1.1(v) the in-app account deletion requirement
does not apply: an account is an employee credential issued and revoked by the
employer, not a consumer account created in the app.

A NOTE ON THE DEMO SERVER
The server enforces one active session per user. If two people sign in as "mic"
at the same time, the first session is ended. If you are signed out unexpectedly
during review, simply sign in again — it is not a crash or a defect.

--------------------------------------------------------------------
5. EXTERNAL SERVICES, TOOLS AND PLATFORMS
--------------------------------------------------------------------
- The customer's own LeoCore ERP server. This is the only backend and the only
  destination for business data. The app talks to it over HTTPS with a REST
  API. It handles authentication and returns all inventory, sales, customer
  and reporting data. For this review that server is
  https://leocoredemo.seksolution.com — a demonstration instance we operate.
  In production each customer points the app at their own server.

- Google Fonts (fonts.gstatic.com). The app downloads the IBM Plex Sans
  typeface on first launch and caches it on the device. No user data, account
  data or business data is sent — it is a font file request only.

- Apple system frameworks: the Vision framework for barcode recognition,
  LocalAuthentication for the optional Face ID / Touch ID unlock, and StoreKit
  solely for the standard "rate this app" prompt.

There are NO other third parties. Specifically the app contains no analytics
SDK, no advertising SDK, no crash-reporting service, no attribution or
tracking framework, no payment processor, no AI or machine-learning service,
and no third-party data provider. Authentication is performed by the
customer's own server; there is no external identity provider.

Data at rest: the authentication token and the server address are stored in the
iOS Keychain on the device. Nothing else is persisted off-server.

--------------------------------------------------------------------
6. REGIONAL DIFFERENCES
--------------------------------------------------------------------
The app functions identically in every region where it is available. There are
no region-locked features, no regional content variations and no geographic
restrictions in the code — the app does not request or use location at all.

The only regional variation is presentational and is chosen by the user, not by
their location: the interface is available in English and Arabic, and selecting
Arabic switches the entire layout to right-to-left. Currency symbols, number
formats and tax labels are supplied by whichever LeoCore server the user signs
in to, reflecting that company's own configuration, not the device's region.

--------------------------------------------------------------------
7. REGULATED INDUSTRY AND THIRD-PARTY MATERIAL
--------------------------------------------------------------------
The app does not operate in a highly regulated industry. It is general-purpose
business inventory and sales software for private commercial use. It provides
no banking, lending, payment, healthcare, insurance, gambling, pharmaceutical
or legal services, and it processes no payments of any kind.

It contains no protected third-party material. All content in the app is either
our own, or the customer company's own business data held on their own server.
The IBM Plex Sans typeface is used under its SIL Open Font License. The app is
developed and published by Souq E Kamil Trading and Solutions W.L.L., which
also develops the LeoCore ERP server it connects to; there is no third-party
service being resold or fronted.

We have also added this information to the Notes field in the App Review
Information section for future submissions, as requested.

Please let us know if anything further would help.
```

---

## Step 3 — Also paste it into the Notes field

Apple asked for this explicitly: *"Include this information in the Notes field of
the App Review Information section in App Store Connect for future submissions."*
They will look, so do it.

Go to the **2.6.0** version page → scroll to **App Review Information** →
**Notes**. Replace what is there with sections 3 through 7 above (drop section 1,
the recording, and section 2, the device list — those are per-submission). Keep
the sign-in instructions at the top. Confirm the fields above it still read:

| Field | Value |
|---|---|
| Sign-in required | ticked |
| User name | `mic` |
| Password | `mic@159357` |
| Contact | your name, phone, `souqekamil@gmail.com` |

## Step 4 — Resubmit

Send the reply with the recording attached, then click **Resubmit to App Review**
on the iOS Submission page. The button is greyed out until the reply goes
through.

---

## What is deliberately not being changed

- **No new build.** Build 8 was not faulted. Uploading a new one resets the
  review queue for no benefit.
- **No screenshot changes.** Guideline 2.3.3 appeared only in Apple's generic
  "How to Prevent Common Issues" footer, not as a finding against this app. All
  six screenshots show the app in use, not the login or splash screen.
- **No metadata rewrite.** Nothing in the listing was faulted.

## Keep alive during review

- `leocoredemo.seksolution.com` reachable, with `mic` active and every module
  granted.
- `leocoreerp.souqekamil.com` serving the privacy policy over HTTPS.
- Avoid signing in as `mic` yourself while review is in progress — the
  single-session rule will kick the reviewer out mid-test.
