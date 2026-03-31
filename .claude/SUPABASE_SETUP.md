# Supabase Setup Guide for GymBro

This guide will walk you through setting up Supabase for the GymBro iOS app.

## 1. Create a Supabase Project

1. Go to [https://supabase.com](https://supabase.com)
2. Sign in or create an account
3. Click "New Project"
4. Fill in the project details:
   - **Name**: `gymbro`
   - **Database Password**: (generate a strong password and save it securely)
   - **Region**: Choose closest to your users
   - **Pricing Plan**: Start with Free tier
5. Click "Create new project"
6. Wait 2-3 minutes for the project to be provisioned

## 2. Get Your Project Credentials

Once the project is ready:

1. Go to **Settings** > **API**
2. Copy these values (you'll need them):
   - **Project URL**: `https://xxxxxxxxxxxxx.supabase.co`
   - **anon/public key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (long JWT token)

## 3. Configure OAuth Providers

### Apple Sign-In Setup

1. Go to **Authentication** > **Providers** in Supabase dashboard
2. Find **Apple** and click to expand
3. Enable Apple provider
4. In Xcode, you'll need:
   - Your Apple Developer Team ID
   - App Bundle ID: `com.gymbro.app.GymBro`
   - Service ID: Create in Apple Developer portal
5. Configure:
   - **Services ID**: Your Apple Service ID
   - **Team ID**: Your Apple Team ID
   - **Key ID**: From Apple Developer portal
   - **Private Key**: Download from Apple Developer portal (p8 file)
6. Add redirect URL: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
7. Save settings

### Google Sign-In Setup

1. Go to **Authentication** > **Providers** in Supabase dashboard
2. Find **Google** and click to expand
3. Enable Google provider
4. Go to [Google Cloud Console](https://console.cloud.google.com)
5. Create a new project or select existing
6. Enable Google+ API
7. Go to **Credentials** > **Create Credentials** > **OAuth 2.0 Client ID**
8. Configure:
   - Application type: **iOS**
   - Name: `GymBro iOS`
   - Bundle ID: `com.gymbro.app.GymBro`
9. Copy the **Client ID**
10. In Supabase, add the Client ID to Google provider settings
11. Add Authorized redirect URIs: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
12. Save settings

## 4. Create Database Tables

Run these SQL commands in Supabase **SQL Editor**:

### Users Table Extension (for profiles)

```sql
-- Create user profiles table
CREATE TABLE public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS (Row Level Security)
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own profile
CREATE POLICY "Users can read own profile"
    ON public.user_profiles
    FOR SELECT
    USING (auth.uid() = id);

-- Policy: Users can update their own profile
CREATE POLICY "Users can update own profile"
    ON public.user_profiles
    FOR UPDATE
    USING (auth.uid() = id);

-- Policy: Users can insert their own profile
CREATE POLICY "Users can insert own profile"
    ON public.user_profiles
    FOR INSERT
    WITH CHECK (auth.uid() = id);

-- Create function to handle new user profiles
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, email, full_name)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.raw_user_meta_data->>'full_name'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on sign up
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();
```

### Onboarding Data Table

```sql
-- Create enums for onboarding data
CREATE TYPE primary_goal_enum AS ENUM (
    'build_muscle',
    'lose_fat',
    'recomposition',
    'improve_endurance',
    'general_fitness'
);

CREATE TYPE experience_level_enum AS ENUM (
    'beginner',
    'intermediate',
    'advanced'
);

CREATE TYPE equipment_enum AS ENUM (
    'full_gym',
    'dumbbells_only',
    'bodyweight',
    'home_gym'
);

-- Create onboarding_data table
CREATE TABLE public.onboarding_data (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    primary_goal primary_goal_enum NOT NULL,
    primary_sport TEXT NOT NULL,
    experience_level experience_level_enum NOT NULL,
    training_frequency INTEGER NOT NULL CHECK (training_frequency BETWEEN 1 AND 7),
    workout_duration INTEGER NOT NULL CHECK (workout_duration IN (30, 45, 60, 90)),
    available_equipment equipment_enum NOT NULL,
    injuries JSONB DEFAULT '[]',
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE public.onboarding_data ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own onboarding data
CREATE POLICY "Users can read own onboarding data"
    ON public.onboarding_data
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Users can insert their own onboarding data
CREATE POLICY "Users can insert own onboarding data"
    ON public.onboarding_data
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own onboarding data
CREATE POLICY "Users can update own onboarding data"
    ON public.onboarding_data
    FOR UPDATE
    USING (auth.uid() = user_id);

-- Create index for faster lookups
CREATE INDEX idx_onboarding_data_user_id ON public.onboarding_data(user_id);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for onboarding_data
CREATE TRIGGER update_onboarding_data_updated_at
    BEFORE UPDATE ON public.onboarding_data
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();
```

## 5. Configure Your iOS App

### Create Config File

Create a file `GymBro/Services/Auth/SupabaseConfig.xcconfig`:

```
SUPABASE_URL = https://xxxxxxxxxxxxx.supabase.co
SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**IMPORTANT**: Add `*.xcconfig` to `.gitignore` to avoid committing secrets!

### Add to .gitignore

Add these lines to your `.gitignore`:

```
# Supabase Config
*.xcconfig
.env
GymBro/Services/Auth/SupabaseConfig.swift
```

## 6. Test Your Setup

1. Run the iOS app
2. Tap "Continue with Apple" or "Continue with Google"
3. Complete OAuth flow
4. Check Supabase Dashboard > **Authentication** > **Users**
5. Verify new user appears
6. Check **Table Editor** > **user_profiles** to see profile created

## 7. Common Issues & Troubleshooting

### Issue: "Invalid OAuth Redirect URI"
**Solution**: Make sure redirect URIs in Apple/Google console match exactly with Supabase redirect URI

### Issue: "Apple Sign-In not working"
**Solution**:
- Verify Apple Service ID is configured correctly
- Check that Bundle ID matches in Xcode and Apple Developer portal
- Ensure Sign In with Apple capability is enabled in Xcode

### Issue: "Google Sign-In fails"
**Solution**:
- Verify Google OAuth Client ID is for iOS (not web)
- Check Bundle ID matches
- Ensure Google+ API is enabled in Cloud Console

### Issue: "Row Level Security error"
**Solution**: Check that RLS policies are created correctly and auth.uid() is available

## 8. Next Steps

- Set up email templates in **Authentication** > **Email Templates**
- Configure password reset flow (if using email auth later)
- Set up webhooks for custom logic (optional)
- Monitor usage in **Settings** > **Usage**

## Resources

- [Supabase Documentation](https://supabase.com/docs)
- [Supabase Swift Client Docs](https://github.com/supabase/supabase-swift)
- [Apple Sign-In Guide](https://developer.apple.com/sign-in-with-apple/)
- [Google Sign-In Guide](https://developers.google.com/identity)
