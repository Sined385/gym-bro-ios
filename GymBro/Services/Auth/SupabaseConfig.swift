//
//  SupabaseConfig.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import Supabase

/// Supabase configuration for the app
enum SupabaseConfig {

    // MARK: - Client

    /// Shared Supabase client instance — configured via AppEnvironment (xcconfig → Info.plist)
    static let client: SupabaseClient = {
        let env = AppEnvironment.current

        guard let url = URL(string: env.supabaseURL) else {
            fatalError("Invalid Supabase URL: \(env.supabaseURL)")
        }

        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: env.supabaseAnonKey
        )
    }()
}

// MARK: - Helper Extensions

extension SupabaseClient {
    /// Convenience accessor for auth client
    var authClient: AuthClient {
        return auth
    }
}
