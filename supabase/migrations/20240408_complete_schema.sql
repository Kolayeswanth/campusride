-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- Drop existing tables if they exist
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
DROP TABLE IF EXISTS public.colleges CASCADE;

-- Drop existing functions and triggers
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users CASCADE;

-- Create user profiles table
CREATE TABLE public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('student', 'driver', 'admin')),
    full_name TEXT,
    phone_number TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create driver verification table
CREATE TABLE public.driver_verification (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    license_number TEXT NOT NULL,
    license_expiry DATE NOT NULL,
    vehicle_type TEXT NOT NULL,
    verification_status TEXT NOT NULL CHECK (verification_status IN ('pending', 'approved', 'rejected')),
    verification_date TIMESTAMPTZ,
    created_at TIMESTATMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create locations table (generic locations table)
CREATE TABLE public.locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    location GEOGRAPHY(POINT) NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('stop', 'landmark', 'other')),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create routes table
CREATE TABLE public.routes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create route stops table (junction table)
CREATE TABLE public.route_stops (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id UUID REFERENCES public.routes(id) ON DELETE CASCADE,
    location_id UUID REFERENCES public.locations(id) ON DELETE CASCADE,
    stop_order INTEGER NOT NULL,
    estimated_time INTEGER, -- in minutes
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(route_id, stop_order)
);

-- Create trips table
CREATE TABLE public.trips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id UUID REFERENCES public.routes(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES public.user_profiles(id),
    status TEXT NOT NULL CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled')),
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create driver trips table (for driver-specific trip information)
CREATE TABLE public.driver_trips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id UUID REFERENCES public.trips(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    vehicle_type TEXT NOT NULL,
    vehicle_number TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(trip_id)
);

-- Create trip locations table for real-time tracking
CREATE TABLE public.trip_locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id UUID REFERENCES public.trips(id) ON DELETE CASCADE,
    location GEOGRAPHY(POINT) NOT NULL,
    heading DOUBLE PRECISION,
    speed DOUBLE PRECISION,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create trip history table (for completed trips)
CREATE TABLE public.trip_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id UUID REFERENCES public.trips(id) ON DELETE CASCADE,
    route_id UUID REFERENCES public.routes(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES public.user_profiles(id),
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    passenger_count INTEGER DEFAULT 0,
    average_speed DOUBLE PRECISION,
    distance_covered DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create trip passengers table
CREATE TABLE public.trip_passengers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id UUID REFERENCES public.trips(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    pickup_location_id UUID REFERENCES public.locations(id),
    dropoff_location_id UUID REFERENCES public.locations(id),
    status TEXT NOT NULL CHECK (status IN ('booked', 'boarding', 'onboard', 'dropped', 'cancelled')),
    booking_time TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(trip_id, user_id)
);

-- Create user locations table for real-time tracking
CREATE TABLE public.user_locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    location GEOGRAPHY(POINT) NOT NULL,
    heading DOUBLE PRECISION,
    speed DOUBLE PRECISION,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create favorite routes table
CREATE TABLE public.favorite_routes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    route_id UUID REFERENCES public.routes(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, route_id)
);

-- Create notifications table
CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('info', 'warning', 'error', 'success')),
    read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create colleges table
CREATE TABLE public.colleges (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    address text NOT NULL,
    code text NOT NULL,
    contact_phone text NULL,
    contact_email text NULL,
    logo_url text NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NULL
);

-- Explicitly drop policies and disable RLS for colleges table
DROP POLICY IF EXISTS "Anyone can view colleges" ON public.colleges;
DROP POLICY IF EXISTS "Authenticated can manage colleges" ON public.colleges;
DROP POLICY IF EXISTS "Anyone can insert colleges" ON public.colleges;
ALTER TABLE public.colleges DISABLE ROW LEVEL SECURITY;

-- Enable Row Level Security for other tables (Disable for colleges)
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_verification ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.route_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_passengers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorite_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Create policies for user_profiles (Keep these as they are not related to colleges)
CREATE POLICY "Users can view their own profile"
    ON public.user_profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON public.user_profiles FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Enable insert for authenticated users"
    ON public.user_profiles FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Create policies for driver_verification (Keep these)
CREATE POLICY "Users can view their own verification"
    ON public.driver_verification FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can insert their own verification"
    ON public.driver_verification FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Only admins can update verification status"
    ON public.driver_verification FOR UPDATE
    USING (EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid() AND role = 'admin'
    ));

-- Create policies for locations (Keep these)
CREATE POLICY "Anyone can view locations"
    ON public.locations FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Anyone can manage locations"
    ON public.locations FOR ALL
    TO authenticated
    USING (true);

-- Create policies for routes (Keep these)
CREATE POLICY "Anyone can view routes"
    ON public.routes FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Anyone can manage routes"
    ON public.routes FOR ALL
    TO authenticated
    USING (true);

-- Create policies for route_stops (Keep these)
CREATE POLICY "Anyone can view route stops"
    ON public.route_stops FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Anyone can manage route stops"
    ON public.route_stops FOR ALL
    TO authenticated
    USING (true);

-- Policies for colleges have been removed

-- Create policies for trips (Keep these)
CREATE POLICY "Anyone can view trips"
    ON public.trips FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Drivers can update their trips"
    ON public.trips FOR UPDATE
    TO authenticated
    USING (driver_id = auth.uid());

CREATE POLICY "Only admins can create trips"
    ON public.trips FOR INSERT
    TO authenticated
    WITH CHECK (EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid() AND role = 'admin'
    ));

-- Create policies for driver_trips (Keep these)
CREATE POLICY "Anyone can view driver trips"
    ON public.driver_trips FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Drivers can update their driver trips"
    ON public.driver_trips FOR UPDATE
    TO authenticated
    USING (driver_id = auth.uid());

CREATE POLICY "Only admins can create driver trips"
    ON public.driver_trips FOR INSERT
    TO authenticated
    WITH CHECK (EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid() AND role = 'admin'
    ));

-- Create policies for trip_locations (Keep these)
CREATE POLICY "Anyone can view trip locations"
    ON public.trip_locations FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Drivers can insert trip locations"
    ON public.trip_locations FOR INSERT
    TO authenticated
    WITH CHECK (EXISTS (
        SELECT 1 FROM public.trips
        WHERE id = trip_id AND driver_id = auth.uid()
    ));

-- Create policies for trip_history (Keep these)
CREATE POLICY "Anyone can view trip history"
    ON public.trip_history FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Only system can insert trip history"
    ON public.trip_history FOR INSERT
    TO authenticated
    WITH CHECK (EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid() AND role = 'admin'
    ));

-- Create policies for trip_passengers (Keep these)
CREATE POLICY "Users can view their own trip passengers"
    ON public.trip_passengers FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "Users can insert their own trip passengers"
    ON public.trip_passengers FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own trip passengers"
    ON public.trip_passengers FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "Drivers can view passengers for their trips"
    ON public.trip_passengers FOR SELECT
    TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.trips
        WHERE id = trip_id AND driver_id = auth.uid()
    ));

-- Create policies for user_locations (Keep these)
CREATE POLICY "Users can view their own location"
    ON public.user_locations FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "Users can update their own location"
    ON public.user_locations FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- Create policies for favorite_routes (Keep these)
CREATE POLICY "Users can view their favorite routes"
    ON public.favorite_routes FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "Users can manage their favorite routes"
    ON public.favorite_routes FOR ALL
    TO authenticated
    USING (user_id = auth.uid());

-- Create policies for notifications (Keep these)
CREATE POLICY "Users can view their notifications"
    ON public.notifications FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "Users can update their notifications"
    ON public.notifications FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid());

-- Create function to handle new user creation (Keep this)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, role)
  VALUES (NEW.id, NEW.email, 'student')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user creation (Keep this)
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create indexes for better performance (Keep these)
CREATE INDEX idx_trip_locations_trip_id ON public.trip_locations(trip_id);
CREATE INDEX idx_user_locations_user_id ON public.user_locations(user_id);
CREATE INDEX idx_trips_route_id ON public.trips(route_id);
CREATE INDEX idx_trips_driver_id ON public.trips(driver_id);
CREATE INDEX idx_route_stops_route_id ON public.route_stops(route_id);
CREATE INDEX idx_route_stops_location_id ON public.route_stops(location_id);
CREATE INDEX idx_trip_passengers_trip_id ON public.trip_passengers(trip_id);
CREATE INDEX idx_trip_passengers_user_id ON public.trip_passengers(user_id);
CREATE INDEX idx_driver_trips_trip_id ON public.driver_trips(trip_id);
CREATE INDEX idx_driver_trips_driver_id ON public.driver_trips(driver_id);
CREATE INDEX idx_driver_verification_user_id ON public.driver_verification(user_id);

-- Enable realtime for specific tables (Keep these if needed, re-add colleges if necessary after fixing the insert)
ALTER PUBLICATION supabase_realtime ADD TABLE public.trip_locations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_locations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.trips;
ALTER PUBLICATION supabase_realtime ADD TABLE public.trip_passengers;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.colleges; -- Add back if realtime is needed after insert works