Push alerts backend (Supabase project ksuvjhutalvwgikvsdeu).
- setup.sql: run once in the SQL Editor (tables, subscribe functions, every-minute cron job).
- Edge function `squares-alerts` (JWT verification off) is deployed from the dashboard; secrets VAPID_PUBLIC_KEY / VAPID_PRIVATE_KEY are set there (private key is NOT stored in this repo).
