//
//  GraphClient.swift
//  IngraphCore
//
//  One-file auth wrapper for Microsoft Graph / Intune.
//
//  ▸ Step-1  read ~/.azure/service_principal_entries.json
//      ├─ if entry contains client_secret  → client-credential flow
//      └─ else                             → public-client + device-code flow
//
//  ▸ Step-2  store/refresh token in ~/.ingraph/token.json
//  ▸ NO .env dependency.
//

import Foundation

// MARK: ––––– public surface ––––––––––––––––––––––––––––––––––––––––––––

public actor GraphAPIClient {

    // singleton
    public static let shared = GraphAPIClient()

    // --------------------------------------------------------------------
    //  PUBLIC HELPERS  (called by CLI / GUI)
    // --------------------------------------------------------------------

    /// CLI: `ingraphutil --login` → only needed for delegated/device-code mode
    public func loginInteractive() async throws {
        guard case .delegated = mode else {
            print("✔︎  Service-principal mode: no interactive login needed")
            return
        }
        _ = try await deviceCodeToken(promptUser: true)
    }

    public func lookup(serials: [String]) async throws -> [Device] {
        try await withThrowingTaskGroup(of: Device?.self) { g in
            let tok = try await token()

            for s in serials {
                g.addTask {
                    let q = s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                    var r = URLRequest(url: URL(string:
                      "https://graph.microsoft.com/beta/deviceManagement/managedDevices?$filter=serialNumber eq '\(q)'")!)
                    r.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")

                    let (d, _) = try await URLSession.shared.data(for: r)
                    guard
                        let js = try JSONSerialization.jsonObject(with:d) as? [String:Any],
                        let v  = (js["value"] as? [[String:Any]])?.first,
                        let id = v["id"] as? String
                    else { return nil }

                    return Device(id: id,
                                  serialNumber: s,
                                  userPrincipalName: v["userPrincipalName"] as? String)
                }
            }

            var out:[Device] = []
            for try await maybe in g { if let d = maybe { out.append(d) } }
            return out
        }
    }

    public func perform(_ cmd: MDMCommand, on devs:[Device]) async throws {
        let tok = try await token()
        for d in devs {
            let (path, body):(String,[String:Any]?) = switch cmd {
            case .sync:         ("/syncDevice",          nil)
            case .reboot:       ("/rebootNow",           nil)
            case .retire:       ("/retire",              nil)
            case .wipe:         ("/wipe",                nil)
            case .scanDefender: ("/windowsDefenderScan", ["quickScan":true])
            case .customScript: ("",                     nil)
            }

            var r = URLRequest(url: URL(string:
              "https://graph.microsoft.com/beta/deviceManagement/managedDevices/\(d.id)\(path)")!)
            r.httpMethod = "POST"
            r.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            if let body {
                r.httpBody = try JSONSerialization.data(withJSONObject: body)
                r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            let (_, rsp) = try await URLSession.shared.data(for: r)
            guard (rsp as! HTTPURLResponse).statusCode < 300 else {
                throw NSError(domain:"Graph",code:(rsp as! HTTPURLResponse).statusCode)
            }
        }
    }

    // MARK: ––––– internal init / auth plumbing ––––––––––––––––––––––––––

    // auth modes ----------------------------------------------------------

    private enum Mode {
        case servicePrincipal(SPEntry)
        case delegated(PublicClient)   // tenant + client_id
    }
    private struct PublicClient { let tenant:String; let clientId:String }

    private let mode : Mode           // decided once in init
    private var accessToken : String? // start out nil
    private var expiry      : Date    // must be given an initial value

    private init() {

        //-----------------------------------------------------------------------
        // 1 · choose auth mode from ~/.azure/service_principal_entries.json
        //-----------------------------------------------------------------------
        guard let entry = try? Self.loadSP() else {
            fatalError("""
            ❗️  ~/.azure/service_principal_entries.json not found (or unreadable).

                [
                  { "tenant": "…", "client_id": "…", "client_secret": "" }
                ]

            """)
        }

        if entry.client_secret.isEmpty {
            mode = .delegated(.init(tenant: entry.tenant,
                                    clientId: entry.client_id))
        } else {
            mode = .servicePrincipal(entry)
        }

        //-----------------------------------------------------------------------
        // 2 · prepare initial token state *before* we touch self.[property]
        //-----------------------------------------------------------------------
        var cachedToken : String? = nil
        var cachedExpiry = Date.distantPast

        if case .delegated = mode,
           let cache = try? GraphAPIClient.readTokenCache(),
           cache.expiry > Date()                // still valid
        {
            cachedToken  = cache.token
            cachedExpiry = cache.expiry
        }

        //-----------------------------------------------------------------------
        // 3 · now we can safely initialise the stored properties
        //-----------------------------------------------------------------------
        self.accessToken = cachedToken
        self.expiry      = cachedExpiry
    }

    // ====================================================================
    //  token()  – central entry
    // ====================================================================
    public func token() async throws -> String {
        if Date() < expiry, let t = accessToken { return t }

        switch mode {
        case .servicePrincipal(let sp):
            return try await clientCredentialToken(sp: sp)

        case .delegated:
            return try await deviceCodeToken(promptUser: false)
        }
    }

    // --------------------------------------------------------------------
    //  MARK:  service-principal  (client-credential flow)
    // --------------------------------------------------------------------
    private struct SPEntry:Decodable { let tenant:String; let client_id:String; let client_secret:String }

    private static func loadSP() throws -> SPEntry? {
        let url = FileManager.default.homeDirectoryForCurrentUser
              .appendingPathComponent(".azure/service_principal_entries.json")
        let d = try Data(contentsOf: url)
        let list = try JSONDecoder().decode([SPEntry].self, from: d)
        // choose *first* entry; extend if you want smarter selection
        return list.first
    }

    private func clientCredentialToken(sp:SPEntry) async throws -> String {

        var r = URLRequest(url: URL(string:
            "https://login.microsoftonline.com/\(sp.tenant)/oauth2/v2.0/token")!)
        r.httpMethod = "POST"
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField:"Content-Type")
        r.httpBody = """
            client_id=\(sp.client_id)&client_secret=\(sp.client_secret)&grant_type=client_credentials&scope=https://graph.microsoft.com/.default
            """.data(using:.utf8)!

        let (d, _) = try await URLSession.shared.data(for: r)
        guard
            let js  = try JSONSerialization.jsonObject(with:d) as? [String:Any],
            let tok = js["access_token"] as? String,
            let exp = js["expires_in"]   as? Int
        else { throw NSError(domain:"Ingraph", code:1,
                             userInfo:[NSLocalizedDescriptionKey:"bad token response"]) }

        accessToken = tok
        expiry      = Date().addingTimeInterval(TimeInterval(exp-60))
        return tok
    }

    // --------------------------------------------------------------------
    //  MARK:  delegated flow  (device-code)
    // --------------------------------------------------------------------
    private struct DCResp:Decodable {
        let device_code:String; let user_code:String
        let verification_uri:String; let expires_in:Int; let interval:Int; let message:String
    }
    private struct TokResp:Decodable {
        let access_token:String; let expires_in:Int; let scope:String; let token_type:String
    }

    private let delegatedScopes = [
        "https://graph.microsoft.com/DeviceManagementServiceConfig.ReadWrite.All",
        "https://graph.microsoft.com/Device.ReadWrite.All",
        "offline_access"
    ]

    private func deviceCodeToken(promptUser:Bool) async throws -> String {
        let pc:PublicClient
        switch mode {
        case .delegated(let p): pc = p
        case .servicePrincipal: fatalError("logic")   // won’t happen
        }

        // 1 · device-code start
        var r = URLRequest(url: URL(string:
            "https://login.microsoftonline.com/\(pc.tenant)/oauth2/v2.0/devicecode")!)
        r.httpMethod = "POST"
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField:"Content-Type")
        r.httpBody = "client_id=\(pc.clientId)&scope=\(delegatedScopes.joined(separator:"%20"))"
            .data(using:.utf8)!
        let (d, _) = try await URLSession.shared.data(for: r)
        let dc = try JSONDecoder().decode(DCResp.self, from: d)

        if promptUser { print("🔑  \(dc.message)") }

        // 2 · poll loop
        let tok = try await pollForToken(pc: pc, dc: dc)
        accessToken = tok.access_token
        expiry      = Date().addingTimeInterval(TimeInterval(tok.expires_in-60))
        try GraphAPIClient.writeTokenCache(.init(token: tok.access_token, expiry: expiry))
        return tok.access_token
    }

    private func pollForToken(pc:PublicClient, dc:DCResp) async throws -> TokResp {
        let url = URL(string:
            "https://login.microsoftonline.com/\(pc.tenant)/oauth2/v2.0/token")!
        while true {
            try await Task.sleep(nanoseconds: UInt64(dc.interval)*1_000_000_000)
            var r = URLRequest(url:url); r.httpMethod = "POST"
            r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField:"Content-Type")
            r.httpBody = "grant_type=device_code&client_id=\(pc.clientId)&device_code=\(dc.device_code)"
                .data(using:.utf8)!
            let (d, _) = try await URLSession.shared.data(for: r)
            if let tok = try? JSONDecoder().decode(TokResp.self, from:d) { return tok }
            // else not ready – keep looping
        }
    }

    // --------------------------------------------------------------------
    //  MARK:  tiny JSON cache  (~/.ingraph/token.json)
    // --------------------------------------------------------------------
    private struct Cache: Codable { let token: String; let expiry: Date }

    /// cache file lives in the user’s home directory
    /// (static & non-isolated ⇒ accessible from anywhere)
    private static let tokenFileURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ingraph/token.json")
    }()

    /// pure synchronous read – safe to call from non-isolated code
    private nonisolated static func readTokenCache() throws -> Cache {
        let data = try Data(contentsOf: tokenFileURL)
        return try JSONDecoder().decode(Cache.self, from: data)
    }

    /// pure synchronous write – ditto
    private nonisolated static func writeTokenCache(_ c: Cache) throws {
        let dir = tokenFileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir,
                                                withIntermediateDirectories: true)
        try JSONEncoder().encode(c).write(to: tokenFileURL,
                                          options: .atomic)
    }
}