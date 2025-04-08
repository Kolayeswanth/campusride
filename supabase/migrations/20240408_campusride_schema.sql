-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- Create user profiles table
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('driver', 'passenger')),
    name TEXT,
    avatar_url TEXT,
    phone_number TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create driver verification table
CREATE TABLE IF NOT EXISTS public.driver_verification (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.user_profiles ON DELETE CASCADE NOT NULL,
    driver_id TEXT NOT NULL,
    license_number TEXT NOT NULL,
    is_verified BOOLEAN DEFAULT FALSE NOT NULL,
    verification_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id)
);

-- Create user locations table
CREATE TABLE IF NOT EXISTS public.user_locations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.user_profiles ON DELETE CASCADE NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('driver', 'passenger')),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    accuracy DOUBLE PRECISION,
    speed DOUBLE PRECISION,
    heading DOUBLE PRECISION,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    location GEOMETRY(Point, 4326) GENERATED ALWAYS AS (st_setsrid(st_makepoint(longitude, latitude), 4326)) STORED
);

-- Create routes table
CREATE TABLE IF NOT EXISTS public.routes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    route_path GEOMETRY(LineString, 4326) NOT NULL,
    start_location GEOMETRY(Point, 4326) NOT NULL,
    end_location GEOMETRY(Point, 4326) NOT NULL,
    estimated_duration INTEGER, -- in minutes
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create trips table
CREATE TABLE IF NOT EXISTS public.trips (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    driver_id UUID REFERENCES public.user_profiles ON DELETE CASCADE NOT NULL,
    route_id UUID REFERENCES public.routes ON DELETE SET NULL,
    status TEXT NOT NULL CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled')),
    start_location GEOMETRY(Point, 4326) NOT NULL,
    end_location GEOMETRY(Point, 4326) NOT NULL,
    route_path GEOMETRY(LineString, 4326),
    scheduled_start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    actual_start_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE,
    capacity INTEGER DEFAULT 50 NOT NULL,
    current_passengers INTEGER DEFAULT 0 NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create trip locations table for tracking
CREATE TABLE IF NOT EXISTS public.trip_locations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    trip_id UUID REFERENCES public.trips ON DELETE CASCADE NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    accuracy DOUBLE PRECISION,
    speed DOUBLE PRECISION,
    heading DOUBLE PRECISION,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    location GEOMETRY(Point, 4326) GENERATED ALWAYS AS (st_setsrid(st_makepoint(longitude, latitude), 4326)) STORED
);

-- Create trip passengers table
CREATE TABLE IF NOT EXISTS public.trip_passengers (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    trip_id UUID REFERENCES public.trips ON DELETE CASCADE NOT NULL,
    passenger_id UUID REFERENCES public.user_profiles ON DELETE CASCADE NOT NULL,
    pickup_location GEOMETRY(Point, 4326) NOT NULL,
    dropoff_location GEOMETRY(Point, 4326) NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('waiting', 'picked_up', 'dropped_off', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(trip_id, passenger_id)
);

-- Create favorite routes table
CREATE TABLE IF NOT EXISTS public.favorite_routes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.user_profiles ON DELETE CASCADE NOT NULL,
    route_id UUID REFERENCES public.routes ON DELETE CASCADE,
    name TEXT NOT NULL,
    start_location GEOMETRY(Point, 4326) NOT NULL,
    end_location GEOMETRY(Point, 4326) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.user_profiles ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('info', 'warning', 'error', 'success')),
    read BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create RLS policies
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_verification ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_passengers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorite_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- User profiles policies
CREATE POLICY "Users can view their own profile"
    ON public.user_profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON public.user_profiles FOR UPDATE
    USING (auth.uid() = id);

-- Driver verification policies
CREATE POLICY "Users can view their own driver verification"
    ON public.driver_verification FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own driver verification"
    ON public.driver_verification FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own driver verification"
    ON public.driver_verification FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- User locations policies
CREATE POLICY "Anyone can view user locations"
    ON public.user_locations FOR SELECT
    USING (true);

CREATE POLICY "Users can insert their own location"
    ON public.user_locations FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own location"
    ON public.user_locations FOR UPDATE
    USING (auth.uid() = user_id);

-- Routes policies
CREATE POLICY "Anyone can view routes"
    ON public.routes FOR SELECT
    USING (true);

CREATE POLICY "Only admins can create routes"
    ON public.routes FOR INSERT
    WITH CHECK (EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid() AND role = 'admin'
    ));

CREATE POLICY "Only admins can update routes"
    ON public.routes FOR UPDATE
    USING (EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid() AND role = 'admin'
    ));

-- Trips policies
CREATE POLICY "Anyone can view trips"
    ON public.trips FOR SELECT
    USING (true);

CREATE POLICY "Drivers can create trips"
    ON public.trips FOR INSERT
    WITH CHECK (
        auth.uid() = driver_id
        AND EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role = 'driver'
        )
    );

CREATE POLICY "Drivers can update their own trips"
    ON public.trips FOR UPDATE
    USING (auth.uid() = driver_id);

-- Trip locations policies
CREATE POLICY "Anyone can view trip locations"
    ON public.trip_locations FOR SELECT
    USING (true);

CREATE POLICY "Drivers can update trip locations"
    ON public.trip_locations FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.trips
            WHERE id = trip_id
            AND driver_id = auth.uid()
        )
    );

-- Trip passengers policies
CREATE POLICY "Users can view their own trip passengers"
    ON public.trip_passengers FOR SELECT
    USING (
        auth.uid() = passenger_id
        OR EXISTS (
            SELECT 1 FROM public.trips
            WHERE id = trip_id
            AND driver_id = auth.uid()
        )
    );

CREATE POLICY "Users can create their own trip passengers"
    ON public.trip_passengers FOR INSERT
    WITH CHECK (auth.uid() = passenger_id);

CREATE POLICY "Users can update their own trip passengers"
    ON public.trip_passengers FOR UPDATE
    USING (auth.uid() = passenger_id);

-- Favorite routes policies
CREATE POLICY "Users can view their own favorite routes"
    ON public.favorite_routes FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create favorite routes"
    ON public.favorite_routes FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own favorite routes"
    ON public.favorite_routes FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own favorite routes"
    ON public.favorite_routes FOR DELETE
    USING (auth.uid() = user_id);

-- Notifications policies
CREATE POLICY "Users can view their own notifications"
    ON public.notifications FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "System can create notifications"
    ON public.notifications FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Users can update their own notifications"
    ON public.notifications FOR UPDATE
    USING (auth.uid() = user_id);

-- Create indexes
CREATE INDEX IF NOT EXISTS user_profiles_role_idx ON public.user_profiles(role);
CREATE INDEX IF NOT EXISTS driver_verification_user_id_idx ON public.driver_verification(user_id);
CREATE INDEX IF NOT EXISTS driver_verification_is_verified_idx ON public.driver_verification(is_verified);
CREATE INDEX IF NOT EXISTS user_locations_user_id_idx ON public.user_locations(user_id);
CREATE INDEX IF NOT EXISTS user_locations_role_idx ON public.user_locations(role);
CREATE INDEX IF NOT EXISTS user_locations_timestamp_idx ON public.user_locations(timestamp);
CREATE INDEX IF NOT EXISTS routes_is_active_idx ON public.routes(is_active);
CREATE INDEX IF NOT EXISTS trips_driver_id_idx ON public.trips(driver_id);
CREATE INDEX IF NOT EXISTS trips_route_id_idx ON public.trips(route_id);
CREATE INDEX IF NOT EXISTS trips_status_idx ON public.trips(status);
CREATE INDEX IF NOT EXISTS trips_scheduled_start_time_idx ON public.trips(scheduled_start_time);
CREATE INDEX IF NOT EXISTS trip_locations_trip_id_idx ON public.trip_locations(trip_id);
CREATE INDEX IF NOT EXISTS trip_locations_timestamp_idx ON public.trip_locations(timestamp);
CREATE INDEX IF NOT EXISTS trip_passengers_trip_id_idx ON public.trip_passengers(trip_id);
CREATE INDEX IF NOT EXISTS trip_passengers_passenger_id_idx ON public.trip_passengers(passenger_id);
CREATE INDEX IF NOT EXISTS trip_passengers_status_idx ON public.trip_passengers(status);
CREATE INDEX IF NOT EXISTS favorite_routes_user_id_idx ON public.favorite_routes(user_id);
CREATE INDEX IF NOT EXISTS favorite_routes_route_id_idx ON public.favorite_routes(route_id);
CREATE INDEX IF NOT EXISTS notifications_user_id_idx ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS notifications_read_idx ON public.notifications(read);

-- Create functions
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, email, role)
    VALUES (new.id, new.email, 'passenger');
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to update trip passenger count
CREATE OR REPLACE FUNCTION public.update_trip_passenger_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.trips
        SET current_passengers = current_passengers + 1
        WHERE id = NEW.trip_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.trips
        SET current_passengers = current_passengers - 1
        WHERE id = OLD.trip_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check trip capacity
CREATE OR REPLACE FUNCTION public.check_trip_capacity()
RETURNS TRIGGER AS $$
DECLARE
    current_count INTEGER;
    max_capacity INTEGER;
BEGIN
    SELECT current_passengers, capacity INTO current_count, max_capacity
    FROM public.trips
    WHERE id = NEW.trip_id;
    
    IF current_count >= max_capacity THEN
        RAISE EXCEPTION 'Trip is at maximum capacity';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

CREATE TRIGGER on_trip_passenger_change
    AFTER INSERT OR DELETE ON public.trip_passengers
    FOR EACH ROW EXECUTE PROCEDURE public.update_trip_passenger_count();

CREATE TRIGGER before_trip_passenger_insert
    BEFORE INSERT ON public.trip_passengers
    FOR EACH ROW EXECUTE PROCEDURE public.check_trip_capacity();

-- Insert some sample routes
INSERT INTO public.routes (name, description, route_path, start_location, end_location, estimated_duration)
VALUES 
    ('Campus Loop', 'Main campus circular route', 
     ST_GeomFromText('LINESTRING(-84.3963 33.7756, -84.3960 33.7758, -84.3957 33.7756, -84.3955 33.7753, -84.3957 33.7750, -84.3960 33.7748, -84.3963 33.7750, -84.3965 33.7753, -84.3963 33.7756)', 4326),
     ST_GeomFromText('POINT(-84.3963 33.7756)', 4326),
     ST_GeomFromText('POINT(-84.3963 33.7756)', 4326),
     15),
    ('Library Express', 'Direct route to library', 
     ST_GeomFromText('LINESTRING(-84.3963 33.7756, -84.3960 33.7758, -84.3957 33.7756, -84.3955 33.7753)', 4326),
     ST_GeomFromText('POINT(-84.3963 33.7756)', 4326),
     ST_GeomFromText('POINT(-84.3955 33.7753)', 4326),
     10),
    ('Dorm Shuttle', 'Route connecting all dorms', 
     ST_GeomFromText('LINESTRING(-84.3963 33.7756, -84.3960 33.7758, -84.3957 33.7756, -84.3955 33.7753, -84.3957 33.7750, -84.3960 33.7748)', 4326),
     ST_GeomFromText('POINT(-84.3963 33.7756)', 4326),
     ST_GeomFromText('POINT(-84.3960 33.7748)', 4326),
     20); 