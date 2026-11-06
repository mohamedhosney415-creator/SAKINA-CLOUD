# SAKINA + Supabase

Supabase project URL: https://gjvqewyuqkmgvcpzsssc.supabase.co

## Database migration
Run `supabase/migrations/20261106_align_existing_schema.sql` in Supabase SQL Editor. It preserves existing tables and data; do not drop the public schema.

## Owner account
1. Create your account from the app.
2. In Supabase SQL Editor run:
   ```sql
   update public.profiles
   set role = 'owner'
   where email = 'YOUR_EMAIL@example.com';
   ```
3. Sign out and sign in again to refresh the owner role.

## Build configuration
Pass the Supabase URL and Publishable Key at build time using Dart defines:
```bash
flutter build apk --release --dart-define=SUPABASE_URL=https://gjvqewyuqkmgvcpzsssc.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```
Never put a Supabase Secret or service_role key in the app or repository.

## Cloud data
The app sync design stores each user's exported app state in `public.user_data` as JSON. This is separate from the local JSON export/import page. No Supabase Storage bucket is configured by this migration.
