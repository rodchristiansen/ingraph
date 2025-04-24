# Ingraph

Microsoft Intune and Graph API **device‑actions toolkit** • macOS SwiftUI GUI + CLI

<img src="/Assets.xcassets/AppIcon.appiconset/Icon-macOS-512x512@2x.png" alt="Ingraph" width="300">

## What is Ingraph?

| Surface | When you’d use it |
|---------|-------------------|
| **SwiftUI GUI** | one‑off tasks – paste serials · click action |
| **`ingraphutil` CLI** | scripting, DevOps pipelines, cron jobs |

Ingraph lets Intune administrators trigger **targeted device actions** (Sync, Reboot, Retire, Wipe, Defender scan …) against one or many devices **by serial‑number**.

* 100 % Swift Package (Xcode or `swift build`)
* OAuth 2 **delegated** flow — *no client secret required*
* Access‑ & refresh‑tokens stored in **macOS Keychain** and auto‑renewed
* Drop‑in service‑principal cache for non‑interactive CI/CD use

## Quick start

```bash
# 1 · Clone & build (Swift 6 toolchain / Xcode 16.3+)
$ git clone https://github.com/rodchristiansen/ingraph.git
$ cd ingraph
$ swift build -c release               # ./.build/release/{Ingraph,ingraphutil}

# 2 · (One‑time) login – caches token in Keychain
$ ./.build/release/ingraphutil --login  # opens browser ➜ MFA etc.

# 3 · Run a command
$ ./.build/release/ingraphutil sync C02XXX12345,C02YYY67890
```

To use the GUI:

```bash
$ swift run Ingraph     # or open Package.swift in Xcode
```

## Authentication flow

1. **Service‑principal cache** — if `~/.azure/service_principal_entries.json` contains a `client_secret`, Ingraph performs a confidential‑client flow (fully headless).
2. **Delegated child‑app** — otherwise it tries the *public‑client* child registration (`Ingraph‑client`) that holds only two delegated Intune scopes.
3. **Device‑code Fallback** — first interactive run prints the familiar URL + 9‑character code (handy on headless hosts).
4. **Silent refresh** — refresh‑tokens renew in the background until you revoke them.

## Creating the child app (one‑time)

1. *Entra ID ▸ App registrations ▸ New.*  
   *Name*: **Ingraph‑client** · *Single‑tenant*
2. *Platform* → **Mobile and desktop** · redirect URI `msal<CLIENT_ID>://auth`
3. *API permissions* → **Microsoft Graph** → **Delegated**
   * `DeviceManagementServiceConfig.ReadWrite.All`
   * `Device.ReadWrite.All`
   * `offline_access`
4. **Grant admin consent** (a Global Admin does this once).
5. Copy the *Application (ID)* → either export as env‑vars or add to the json cache below.

### Configuration options

| Var / file | Needed when | Example |
|------------|-------------|---------|
| `AZURE_TENANT_ID` | always | `d22686a0‑…` |
| `AZURE_CLIENT_ID` | if you skip the json file | child‑app GUID |
| `~/.azure/service_principal_entries.json` | CI / headless | see snippet |

`~/.azure/service_principal_entries.json`
```json
[
  {
    "tenant":        "TENANT_ID",
    "client_id":     "CLIENT_ID",
    "client_secret": "CLIENT_SECRET"
  }
]
```

## CLI reference

```text
ingraphutil --login                 # one‑time browser login

ingraphutil sync          <serial[,…]>
ingraphutil reboot         <serial[,…]>
ingraphutil retire         <serial[,…]>
ingraphutil wipe           <serial[,…]>
ingraphutil scandefender   <serial[,…]>
```
Exit codes: **0** success · **1** usage · **2** Graph/API error.

## Extending commands

1. **Models.swift** – add a case to `MDMCommand`.  
2. **GraphClient.perform(_:on:)** – map the new case to a Graph endpoint + JSON body.

Both GUI picker *and* CLI auto‑update on the next build.

## Security posture

* **No secrets on disk** in delegated mode; tokens are Keychain‑encrypted.
* **Least‑privilege** — exactly two Intune delegated scopes, no wildcard Graph access.
* **Instant revocation**  
  • Remove user from *Intune Admins* group **or** delete their refresh‑tokens.  
  • If the app itself is compromised, delete/rotate the public‑client registration.
* **Auditable** — every call is a first‑party Graph request → visible in Entra sign‑ins & Intune audit logs.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| **`invalid_client` · AADSTS7000218** | Public‑client mistakenly has a secret → clear `client_secret` or recreate app |
| **`AADSTS65002` during `az login --scope …`** | Use Ingraph’s delegated client, or just run `ingraphutil --login` |
| **HTTP 403 months later** | Refresh‑token expired → run `--login` again |
| **Build fails on Intel Mac** | Xcode 16.3 + Swift 6 toolchain required |

## License

MIT — see LICENSE.

