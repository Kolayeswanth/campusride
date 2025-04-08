-- Drop all tables in the public schema
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.favorite_routes CASCADE;
DROP TABLE IF EXISTS public.trip_locations CASCADE;
DROP TABLE IF EXISTS public.trips CASCADE;
DROP TABLE IF EXISTS public.user_locations CASCADE;
DROP TABLE IF EXISTS public.user_profiles CASCADE;
DROP TABLE IF EXISTS public.driver_verification CASCADE;
DROP TABLE IF EXISTS public.bus_locations CASCADE;
DROP TABLE IF EXISTS public.buses CASCADE;
DROP TABLE IF EXISTS public.routes CASCADE;

-- Drop all functions
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- Drop all triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users CASCADE;

-- Drop extensions (optional, comment out if you want to keep them)
-- DROP EXTENSION IF EXISTS "postgis" CASCADE;
-- DROP EXTENSION IF EXISTS "uuid-ossp" CASCADE; 