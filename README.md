# Debug Log Viewer — Salesforce LWC Component

A reusable Lightning Web Component that reads **ApexLog** records via the **Salesforce Tooling API** and displays filterable, searchable log output inline — no Setup UI required.

> **Sandbox / Developer Org only.** ApexLog records are not available in production orgs.

---

## Features

| Feature | Description |
|---|---|
| Log list | Paginated table of ApexLog records with user, operation, status, size, and duration |
| Filter bar | Filter by User Id, Operation keyword, and Status |
| Column sort | Client-side sort by Date/Time |
| Load more | Incremental pagination (50 rows per page, max 200) |
| Log detail modal | Full log body in a dark-theme code viewer |
| Category filter | Filter log lines by event type (USER_DEBUG, SOQL_EXECUTE_BEGIN, DML_BEGIN, etc.) |
| Inline search | Full-text search within the log body |
| Copy to clipboard | Copy raw or filtered log content |
| Download | Save log body as a `.log` file |
| Multi-select delete | Checkbox selection + bulk delete via Tooling API composite |
| Toast notifications | Success / error feedback for all async operations |
| Configurable limit | App Builder property controls initial load size |

---

## Architecture

```
┌─────────────────────────────────────────────┐
│           Lightning App / Tab               │
│                                             │
│   ┌─────────────────────────────────────┐   │
│   │        debugLogViewer (parent)      │   │
│   │  ┌──────────────────────────────┐   │   │
│   │  │     debugLogFilter (child)   │   │   │
│   │  └──────────────────────────────┘   │   │
│   │  ┌──────────────────────────────┐   │   │
│   │  │    debugLogDetail (child)    │   │   │
│   │  └──────────────────────────────┘   │   │
│   └─────────────────────────────────────┘   │
│              │ @AuraEnabled                  │
│   ┌──────────▼──────────────────────────┐   │
│   │   DebugLogViewerController (Apex)   │   │
│   └──────────┬──────────────────────────┘   │
│              │ Named Credential callout      │
│   ┌──────────▼──────────────────────────┐   │
│   │    Salesforce Tooling API           │   │
│   │  /tooling/query  (ApexLog list)     │   │
│   │  /tooling/sobjects/ApexLog/{id}/Body│   │
│   │  /tooling/composite/sobjects (DEL)  │   │
└───┴─────────────────────────────────────┴───┘
```

---

## File Structure

```
debug-log-viewer/
├── sfdx-project.json
├── .forceignore
└── force-app/main/default/
    ├── lwc/
    │   ├── debugLogViewer/          ← Parent component (App Builder–exposed)
    │   │   ├── debugLogViewer.html
    │   │   ├── debugLogViewer.js
    │   │   ├── debugLogViewer.css
    │   │   └── debugLogViewer.js-meta.xml
    │   ├── debugLogFilter/          ← Filter bar child component
    │   │   ├── debugLogFilter.html
    │   │   ├── debugLogFilter.js
    │   │   ├── debugLogFilter.css
    │   │   └── debugLogFilter.js-meta.xml
    │   └── debugLogDetail/          ← Log body modal child component
    │       ├── debugLogDetail.html
    │       ├── debugLogDetail.js
    │       ├── debugLogDetail.css
    │       └── debugLogDetail.js-meta.xml
    ├── classes/
    │   ├── DebugLogViewerController.cls
    │   ├── DebugLogViewerController.cls-meta.xml
    │   ├── DebugLogViewerControllerTest.cls
    │   └── DebugLogViewerControllerTest.cls-meta.xml
    ├── namedCredentials/
    │   └── SalesforceToolingAPI.namedCredential-meta.xml
    └── permissionsets/
        └── DebugLogViewer.permissionset-meta.xml
```

---

## Prerequisites

- Salesforce CLI (`sf` / `sfdx`) v2+
- API version 59.0 or later
- A **sandbox** or **Developer Edition** org
- A Connected App with OAuth scopes: `api`, `refresh_token`, `offline_access`

---

## Setup Guide

### Step 1 — Create a Connected App

1. In your sandbox, go to **Setup → App Manager → New Connected App**.
2. Enable **OAuth Settings**.
3. Set **Callback URL** to `https://login.salesforce.com/services/oauth2/callback`.
4. Add OAuth Scopes:
   - `Access and manage your data (api)`
   - `Perform requests on your behalf at any time (refresh_token, offline_access)`
5. Save and note the **Consumer Key** and **Consumer Secret**.

### Step 2 — Create the Named Credential

1. Go to **Setup → Security → Named Credentials → New**.
2. Fill in:
   | Field | Value |
   |---|---|
   | Label | `SalesforceToolingAPI` |
   | Name | `SalesforceToolingAPI` |
   | URL | `https://YOUR-SANDBOX.my.salesforce.com` |
   | Identity Type | Named Principal |
   | Authentication Protocol | OAuth 2.0 |
   | Authentication Provider | *(create one pointing to your Connected App)* |
   | Scope | `api refresh_token` |
3. Save and click **Authenticate** to complete the OAuth flow.

> **Tip:** Create an Auth. Provider first under **Setup → Auth. Providers** using the Connected App credentials.

### Step 3 — Deploy the component

```bash
# Authenticate to your sandbox
sf org login web --instance-url https://test.salesforce.com --alias my-sandbox

# Deploy all metadata
sf project deploy start --source-dir force-app --target-org my-sandbox

# Assign the permission set to yourself
sf org assign permset --name DebugLogViewer --target-org my-sandbox
```

### Step 4 — Add to a Lightning App

1. Go to **Setup → Lightning App Builder**.
2. Open or create an App Page / Home Page.
3. Drag **Debug Log Viewer** from the component panel onto the canvas.
4. Optionally set **Default Log Limit** in the properties panel.
5. **Save & Activate**.

---

## Tooling API Queries Used

| Operation | Endpoint |
|---|---|
| List logs | `GET /tooling/query/?q=SELECT … FROM ApexLog ORDER BY LastModifiedDate DESC LIMIT n` |
| Fetch log body | `GET /tooling/sobjects/ApexLog/{id}/Body` |
| Delete logs | `DELETE /tooling/composite/sobjects?ids={id1},{id2}` |

---

## Component API

### `debugLogViewer` (App Builder property)

| Property | Type | Default | Description |
|---|---|---|---|
| `defaultLimit` | Integer | `50` | Number of logs fetched on first load (max 200) |

### `debugLogFilter` → fires `filterchange`

```js
// detail shape
{
    userId:    String | null,   // 18-char User Id
    operation: String | null,   // keyword substring
    status:    String | null    // 'Success' | 'Problem'
}
```

### `debugLogDetail` → listens to `@api logId`, fires `close`

---

## Log Category Filter Reference

| Category | Meaning |
|---|---|
| `USER_DEBUG` | `System.debug()` statements |
| `SOQL_EXECUTE_BEGIN` | SOQL query start |
| `DML_BEGIN` | DML operation start |
| `EXCEPTION_THROWN` | Caught / uncaught exceptions |
| `FATAL_ERROR` | Unhandled exceptions that abort execution |
| `CALLOUT_REQUEST` | Outbound HTTP callout start |
| `CALLOUT_RESPONSE` | Outbound HTTP callout response |
| `HEAP_ALLOCATE` | Heap allocation events |

---

## Running Tests

```bash
# Run Apex tests
sf apex run test \
  --class-names DebugLogViewerControllerTest \
  --target-org my-sandbox \
  --result-format human \
  --output-dir test-results \
  --wait 10
```

Target coverage: **≥ 85%** (all HTTP callout paths are exercised via `HttpCalloutMock`).

---

## Salesforce Best Practices Applied

- **`with sharing`** on Apex controller — respects org sharing model.
- **Named Credential** for all callouts — no credentials in code.
- **Input sanitisation** — `String.escapeSingleQuotes()` on all SOQL parameters.
- **Id prefix validation** — `07L` prefix check before any callout involving a log Id.
- **`@AuraEnabled(cacheable=false)`** — log data is real-time; never stale-cached.
- **CSP / CORS safe** — no inline scripts; `navigator.clipboard` used for copy.
- **Limit cap** — server-side cap (200) prevents oversized callouts.
- **Child components** use custom events (`filterchange`, `close`) for loose coupling.
- **`lightning-spinner`** and `lightning-badge` — standard SLDS components only.
- **Error boundary** — all async paths return user-friendly messages; no raw stack traces.

---

## Limitations & Considerations

- **Sandbox only** — `ApexLog` is a Tooling API object not available in production.
- **Log retention** — Salesforce auto-purges debug logs after 24 hours or when space is exhausted.
- **Log body size** — Very large logs (>5 MB) may be slow to render in the browser. Consider chunked display for high-volume environments.
- **Named Credential OAuth flow** — must be completed manually in each sandbox after deployment.
- **Concurrency** — Tooling API has a limit of 10 concurrent requests per user session.

---

## License

MIT — free for use in internal Salesforce orgs and ISV packages.
