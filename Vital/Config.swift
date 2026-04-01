import Foundation

enum Config {
    static let supabaseURL = URL(string: "https://ylwlxuexibrraztmxzew.supabase.co")!
    static let supabaseAnonKey = "sb_publishable_hBfD__FBtjKN5Y_Qv5C_Rg_G92Ulr85"

    static let apiBaseURL = URL(string: "https://vital-health-dashboard.vercel.app/api")!
    static let ingestURL = URL(string: "https://vital-health-dashboard.vercel.app/api/ingest/apple-health")!

    static let backgroundTaskIdentifier = "com.vital.health.sync"
    static let defaultSyncLookbackDays = 7
}
