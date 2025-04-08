-- Drop all tables in the public schema
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.favorite_routes CASCADE;
DROP TABLE IF EXISTS public.trip_locations CASCADE;
DROP TABLE IF EXISTS public.trip_passengers CASCADE;
DROP TABLE IF EXISTS public.trip_history CASCADE;
DROP TABLE IF EXISTS public.driver_trips CASCADE;
DROP TABLE IF EXISTS public.trips CASCADE;
DROP TABLE IF EXISTS public.user_locations CASCADE;
DROP TABLE IF EXISTS public.user_profiles CASCADE;
DROP TABLE IF EXISTS public.driver_verification CASCADE;
DROP TABLE IF EXISTS public.locations CASCADE;
DROP TABLE IF EXISTS public.route_stops CASCADE;
DROP TABLE IF EXISTS public.routes CASCADE;
DROP TABLE IF EXISTS public.bus_locations CASCADE;
DROP TABLE IF EXISTS public.buses CASCADE;

-- Drop all functions
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.handle_user_profile() CASCADE;

-- Drop all triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users CASCADE;

-- Drop all policies
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "Users can view their own profile" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Users can update their own profile" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Users can view their own verification" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Users can insert their own verification" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Only admins can update verification status" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Anyone can view locations" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Only admins can manage locations" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Anyone can view routes" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Only admins can manage routes" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Anyone can view route stops" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Only admins can manage route stops" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Anyone can view trips" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Drivers can update their trips" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Only admins can create trips" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Anyone can view driver trips" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Drivers can update their driver trips" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Only admins can create driver trips" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Anyone can view trip locations" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Drivers can insert trip locations" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Anyone can view trip history" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Only system can insert trip history" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Users can view their own trip passengers" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Users can insert their own trip passengers" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Users can update their own trip passengers" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Drivers can view passengers for their trips" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Users can view their own location" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Users can update their own location" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Users can view their favorite routes" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Users can manage their favorite routes" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Users can view their notifications" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
        EXECUTE 'DROP POLICY IF EXISTS "Users can update their notifications" ON public.' || quote_ident(r.tablename) || ' CASCADE;';
    END LOOP;
END $$;

-- Drop all indexes
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE 'DROP INDEX IF EXISTS idx_' || r.tablename || '_id CASCADE;';
        EXECUTE 'DROP INDEX IF EXISTS idx_' || r.tablename || '_created_at CASCADE;';
        EXECUTE 'DROP INDEX IF EXISTS idx_' || r.tablename || '_updated_at CASCADE;';
    END LOOP;
END $$;

-- Drop specific indexes
DROP INDEX IF EXISTS idx_trip_locations_trip_id CASCADE;
DROP INDEX IF EXISTS idx_user_locations_user_id CASCADE;
DROP INDEX IF EXISTS idx_trips_route_id CASCADE;
DROP INDEX IF EXISTS idx_trips_driver_id CASCADE;
DROP INDEX IF EXISTS idx_route_stops_route_id CASCADE;
DROP INDEX IF EXISTS idx_route_stops_location_id CASCADE;
DROP INDEX IF EXISTS idx_trip_passengers_trip_id CASCADE;
DROP INDEX IF EXISTS idx_trip_passengers_user_id CASCADE;
DROP INDEX IF EXISTS idx_driver_trips_trip_id CASCADE;
DROP INDEX IF EXISTS idx_driver_trips_driver_id CASCADE;
DROP INDEX IF EXISTS idx_driver_verification_user_id CASCADE;
DROP INDEX IF EXISTS idx_bus_locations_bus_id CASCADE;

-- Remove tables from realtime publication
ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS public.trip_locations;
ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS public.user_locations;
ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS public.trips;
ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS public.trip_passengers;
ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS public.notifications;
ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS public.bus_locations;

-- Drop extensions (optional, comment out if you want to keep them)
-- DROP EXTENSION IF EXISTS "postgis" CASCADE;
-- DROP EXTENSION IF EXISTS "uuid-ossp" CASCADE;

-- Verify all tables are dropped
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        RAISE NOTICE 'Table still exists: %', r.tablename;
    END LOOP;
END $$; 