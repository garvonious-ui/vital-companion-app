import Foundation

enum Config {
    static let supabaseURL = URL(string: "https://ylwlxuexibrraztmxzew.supabase.co")!
    static let supabaseAnonKey = "sb_publishable_hBfD__FBtjKN5Y_Qv5C_Rg_G92Ulr85"

    #if DEBUG
    static let apiBaseURL = URL(string: "http://localhost:3000/api")!
    static let ingestURL = URL(string: "http://localhost:3000/api/ingest/apple-health")!
    #else
    static let apiBaseURL = URL(string: "https://vital-health-dashboard.vercel.app/api")!
    static let ingestURL = URL(string: "https://vital-health-dashboard.vercel.app/api/ingest/apple-health")!
    #endif

    static let backgroundTaskIdentifier = "com.vital.health.sync"
    static let defaultSyncLookbackDays = 7
}
