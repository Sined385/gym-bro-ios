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

    /// API base URL — set via xcconfig → Info.plist
    var apiBaseURL: String {
        guard let url = Bundle.main.infoDictionary?["API_BASE_URL"] as? String, !url.isEmpty else {
            fatalError("API_BASE_URL not set in Info.plist. Check your xcconfig.")
        }
        return url
    }

    /// Supabase project URL — set via xcconfig → Info.plist
    var supabaseURL: String {
        guard let url = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String, !url.isEmpty else {
            fatalError("SUPABASE_URL not set in Info.plist. Check your xcconfig.")
        }
        return url
    }

    /// Supabase anon key — set via xcconfig → Info.plist
    var supabaseAnonKey: String {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String, !key.isEmpty else {
            fatalError("SUPABASE_ANON_KEY not set in Info.plist. Check your xcconfig.")
        }
        return key
    }
}
