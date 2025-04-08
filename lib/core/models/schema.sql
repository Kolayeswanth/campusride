-- User Profiles Table
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT NOT NULL,
    role TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Bus Information Table
CREATE TABLE IF NOT EXISTS buses (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    capacity INTEGER NOT NULL,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Routes Table
CREATE TABLE IF NOT EXISTS routes (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    start_location TEXT NOT NULL,
    end_location TEXT NOT NULL,
    stops JSONB, -- Array of stops with coordinates
    schedule JSONB, -- Schedule information
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Driver Trips Table
CREATE TABLE IF NOT EXISTS driver_trips (
    id TEXT PRIMARY KEY,
    driver_id UUID REFERENCES auth.users(id) NOT NULL,
    bus_id TEXT REFERENCES buses(id) NOT NULL,
    route_name TEXT NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Bus Location Updates Table
CREATE TABLE IF NOT EXISTS bus_locations (
    id SERIAL PRIMARY KEY,
    bus_id TEXT REFERENCES buses(id) NOT NULL,
    driver_id UUID REFERENCES auth.users(id) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    heading DOUBLE PRECISION,
    speed DOUBLE PRECISION,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Driver Verification Table
CREATE TABLE IF NOT EXISTS driver_verification (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    driver_id TEXT NOT NULL,
    license_number TEXT NOT NULL,
    is_verified BOOLEAN DEFAULT false,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Security Policies

-- Check if policies exist before creating them
DO $$
BEGIN
    -- Policies for user_profiles
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'user_profiles' AND policyname = 'Users can view their own profile'
    ) THEN
        CREATE POLICY "Users can view their own profile" 
        ON user_profiles FOR SELECT 
        USING (auth.uid() = id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'user_profiles' AND policyname = 'Users can update their own profile'
    ) THEN
        CREATE POLICY "Users can update their own profile" 
        ON user_profiles FOR UPDATE 
        USING (auth.uid() = id);
    END IF;

    -- Policies for driver_trips
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'driver_trips' AND policyname = 'Drivers can view their own trips'
    ) THEN
        CREATE POLICY "Drivers can view their own trips" 
        ON driver_trips FOR SELECT 
        USING (auth.uid() = driver_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'driver_trips' AND policyname = 'Drivers can insert their own trips'
    ) THEN
        CREATE POLICY "Drivers can insert their own trips" 
        ON driver_trips FOR INSERT 
        WITH CHECK (auth.uid() = driver_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'driver_trips' AND policyname = 'Drivers can update their own trips'
    ) THEN
        CREATE POLICY "Drivers can update their own trips" 
        ON driver_trips FOR UPDATE 
        USING (auth.uid() = driver_id);
    END IF;

    -- Policies for bus_locations
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'bus_locations' AND policyname = 'Drivers can insert bus locations'
    ) THEN
        CREATE POLICY "Drivers can insert bus locations" 
        ON bus_locations FOR INSERT 
        WITH CHECK (auth.uid() = driver_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'bus_locations' AND policyname = 'Anyone can view bus locations'
    ) THEN
        CREATE POLICY "Anyone can view bus locations" 
        ON bus_locations FOR SELECT 
        USING (true);
    END IF;

    -- Policies for driver_verification
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'driver_verification' AND policyname = 'Drivers can insert their verification data'
    ) THEN
        CREATE POLICY "Drivers can insert their verification data" 
        ON driver_verification FOR INSERT 
        WITH CHECK (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'driver_verification' AND policyname = 'Drivers can view their verification status'
    ) THEN
        CREATE POLICY "Drivers can view their verification status" 
        ON driver_verification FOR SELECT 
        USING (auth.uid() = user_id);
    END IF;
END
$$;

-- Enable Row Level Security
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE bus_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_verification ENABLE ROW LEVEL SECURITY; 