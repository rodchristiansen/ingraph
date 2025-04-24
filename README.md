# Ingraph
> Intune • Microsoft Graph • macOS SwiftUI GUI & CLI

---

## What Is It?
**Ingraph** is a macOS desktop app + CLI that lets you run targeted Microsoft Intune / Graph API actions (sync, reboot, retire, wipe, Defender scan, …) against one or more devices by serial number.

* **GUI** – quick, paste‑serials‑&‑click workflow
* **`ingraphutil` CLI** – script or pipeline friendly
* **Auth** – secure delegated OAuth 2.0 device‑code flow, no secrets
* **No platform lock‑in** – standard Swift PM package; open with Xcode or build via `swift build`

---

## Prerequisites
| Requirement | Why |
|-------------|-----|
| **macOS 14+** | Swift 6 concurrency & SwiftUI runtime |
| **Swift 6 toolchain / Xcode 16.3+** | builds the package |
| **Azure AD app registration (public‑client)** | delegated auth for API permissions |

---

## 1 · Create the Azure AD Child App

1. **Azure Portal → Entra ID → App registrations → New**.
2. *Name*: `Ingraph‑client`.
3. *Account type*: *Single‑tenant* (recommended).
4. *Platform*: *Mobile and desktop* ➜ redirect URI `msal<CLIENT_ID>://auth`.
5. *Add delegated API permissions* → **Microsoft Graph**
   * `DeviceManagementServiceConfig.ReadWrite.All`
   * `Device.ReadWrite.All`
   * `offline_access` (under *OpenID permissions*)
6. *Grant admin consent* for those three scopes.
7. Copy the **Application (ID)** ⇒ `AZURE_CLIENT_ID`.

> **Why a child app?**
> Your production “parent” app might have powerful application roles.
> This public‑client holds **only** the two delegated scopes, no secret, no
> app‑roles – keeping blast radius minimal.

---

## 2 · One‑Time Login (device‑code)

```bash
az login \
  --tenant   <AZURE_TENANT_ID> \
  --client-id <AZURE_CLIENT_ID> \
  --scope "https://graph.microsoft.com/DeviceManagementServiceConfig.ReadWrite.All https://graph.microsoft.com/Device.ReadWrite.All"

Azure CLI prints a URL + 9‑character code.
Open the URL, enter the code, complete MFA.
After success, Azure CLI silently refreshes tokens for up to 90 days.


## 3 · Clone & Build

git clone https://github.com/your‑org/ingraph.git
cd ingraph

# export once or add to ~/.zshrc
export AZURE_TENANT_ID=<tenant-guid>
export AZURE_CLIENT_ID=<client-guid>

# GUI
swift run Ingraph                   # or open Package.swift in Xcode

# CLI example
swift run ingraphutil sync C02XXX12345,C02YYY67890




## 4 · GUI Usage
    1.    Paste one or more serial numbers (comma, space, or newline separated).
    2.    Click Lookup – devices appear with their userPrincipalName.
    3.    Choose an action: Sync, Reboot, Retire, Wipe, Defender scan, …
    4.    Click Run.
    5.    Status lines stream in the log pane.

Auth happens automatically: silent refresh → device‑code prompt (only if
needed).


## 5 · CLI Usage

# general pattern
ingraphutil <command> <serial[,serial…]>

# examples
ingraphutil sync   C02XXX12345
ingraphutil wipe   C02XXX12345,C02YYY67890
ingraphutil reboot C02ZZZ99999

Exit codes: 0 success, 1 wrong args, 2 Graph error.


## 6 · Extending Commands

Sources/IngraphCore/Models.swift

enum MDMCommand {
    case yourNewCommand
}

GraphClient.run(_:on:) – add the Graph endpoint + body.
The GUI picker and CLI auto‑update.


## 7 · Project Structure

.
├── Package.swift           ← Swift PM manifest
├── Sources
│   ├── IngraphCore         ← shared Graph client + models
│   ├── IngraphApp          ← SwiftUI GUI
│   └── IngraphCLI          ← headless executable
└── README.md




## 8 · Security Notes
    •    Device‑code flow = no client secret.
    •    Tokens cached in Keychain by MSAL, encrypted at rest.
    •    Scopes scoped – only two delegated permissions, no Graph wildcard.
    •    Revoke by deleting the app registration or per‑user refresh tokens.


## Troubleshooting

Symptom    Fix
“No account matching identifier”    Run az logout then repeat az login …
HTTP 403 after months    Device‑code token lifetime ended → rerun az login …
Status 429    You’re rate‑limited; back off or batch requests
Build fails on Intel Mac    Ensure Xcode 16.3+, set toolchain to Swift 6 preview




## License

MIT — see LICENSE.


