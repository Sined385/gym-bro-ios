//
//  AppEnvironment.swift
//  GymBro
//

import Foundation

enum AppEnvironment {
    case development
    case staging
    case production

    static var current: AppEnvironment {
        #if PRODUCTION
        return .production
        #elseif STAGING
        return .staging
        #else
        return .development
        #endif
    }

    /// API base URL — reads from Info.plist (set via xcconfig), falls back to defaults
    var apiBaseURL: String {
        if let url = Bundle.main.infoDictionary?["API_BASE_URL"] as? String, !url.isEmpty {
            return url
        }
        switch self {
        case .development:
            return "http://localhost:3001"
        case .staging:
            return "https://gym-bro-api-staging.up.railway.app"
        case .production:
            return "https://gym-bro-api-production.up.railway.app"
        }
    }

    /// Supabase project URL
    var supabaseURL: String {
        if let url = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String, !url.isEmpty {
            return url
        }
        switch self {
        case .development:
            return "http://127.0.0.1:54321"
        case .staging:
            return "https://pzyjxzhdnamkljjeayno.supabase.co"
        case .production:
            return "https://pzyjxzhdnamkljjeayno.supabase.co"
        }
    }

    /// Supabase anon key
    var supabaseAnonKey: String {
        if let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String, !key.isEmpty {
            return key
        }
        switch self {
        case .development:
            return "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"
        case .staging:
            return "sb_publishable_dRg8kfSg53w385Z205QITA_dlRWDEiF"
        case .production:
            return "sb_publishable_dRg8kfSg53w385Z205QITA_dlRWDEiF"
        }
    }
}
