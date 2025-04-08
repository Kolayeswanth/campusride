-- First, drop existing tables to start fresh
DROP TABLE IF EXISTS route_stops CASCADE;
DROP TABLE IF EXISTS bus_locations CASCADE;
DROP TABLE IF EXISTS buses CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;

-- Create user profiles table to store user roles
CREATE TABLE user_profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('driver', 'passenger')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create buses table
CREATE TABLE buses (
  id TEXT PRIMARY KEY,
  route_name TEXT NOT NULL,
  driver_id UUID REFERENCES auth.users(id),
  driver_name TEXT NOT NULL,
  driver_phone TEXT,
  capacity INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create bus locations table to store real-time location data
CREATE TABLE bus_locations (
  bus_id TEXT PRIMARY KEY REFERENCES buses(id),
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  speed DOUBLE PRECISION,
  heading DOUBLE PRECISION,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create route stops table
CREATE TABLE route_stops (
  id SERIAL PRIMARY KEY,
  bus_id TEXT REFERENCES buses(id),
  stop_name TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  order_number INTEGER NOT NULL,
  arrival_time TIME,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE buses ENABLE ROW LEVEL SECURITY;
ALTER TABLE bus_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE route_stops ENABLE ROW LEVEL SECURITY;

-- Important: Drop all existing policies first
DROP POLICY IF EXISTS "Users can read their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Anyone can insert user profiles" ON user_profiles;
DROP POLICY IF EXISTS "Anyone can read active buses" ON buses;
DROP POLICY IF EXISTS "Drivers can update their assigned buses" ON buses;
DROP POLICY IF EXISTS "Anyone can read bus locations" ON bus_locations;
DROP POLICY IF EXISTS "Drivers can update their bus location" ON bus_locations;
DROP POLICY IF EXISTS "Anyone can read route stops" ON route_stops;

-- USER PROFILES POLICIES

-- Allow public inserts for user_profiles (crucial for registration flow)
CREATE POLICY "Public insert for user_profiles"
  ON user_profiles FOR INSERT
  WITH CHECK (true);

-- Allow users to read their own profile
CREATE POLICY "Users can read their own profile"
  ON user_profiles FOR SELECT
  USING (auth.uid() = id);

-- Allow users to update their own profile
CREATE POLICY "Users can update their own profile"
  ON user_profiles FOR UPDATE
  USING (auth.uid() = id);

-- BUSES POLICIES

-- Anyone can read active buses
CREATE POLICY "Anyone can read active buses"
  ON buses FOR SELECT
  USING (is_active = true);

-- Only drivers can update their assigned buses
CREATE POLICY "Drivers can update their assigned buses"
  ON buses FOR UPDATE
  USING (auth.uid() = driver_id);

-- Only drivers can insert their buses
CREATE POLICY "Drivers can insert buses"
  ON buses FOR INSERT
  WITH CHECK (auth.uid() = driver_id);

-- BUS LOCATIONS POLICIES

-- Anyone can read bus locations
CREATE POLICY "Anyone can read bus locations"
  ON bus_locations FOR SELECT
  USING (true);

-- Only drivers can insert their bus location
CREATE POLICY "Drivers can insert bus locations"
  ON bus_locations FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM buses
      WHERE buses.id = bus_locations.bus_id
      AND buses.driver_id = auth.uid()
    )
  );

-- Only drivers can update their bus location
CREATE POLICY "Drivers can update bus locations"
  ON bus_locations FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM buses
      WHERE buses.id = bus_locations.bus_id
      AND buses.driver_id = auth.uid()
    )
  );

-- ROUTE STOPS POLICIES

-- Anyone can read route stops
CREATE POLICY "Anyone can read route stops"
  ON route_stops FOR SELECT
  USING (true);

-- Only drivers can insert route stops for their buses
CREATE POLICY "Drivers can insert route stops"
  ON route_stops FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM buses
      WHERE buses.id = route_stops.bus_id
      AND buses.driver_id = auth.uid()
    )
  );

-- Only drivers can update route stops for their buses
CREATE POLICY "Drivers can update route stops"
  ON route_stops FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM buses
      WHERE buses.id = route_stops.bus_id
      AND buses.driver_id = auth.uid()
    )
  );

-- Create functions and triggers

-- Function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE PROCEDURE update_updated_at_timestamp();

CREATE TRIGGER update_buses_updated_at
  BEFORE UPDATE ON buses
  FOR EACH ROW
  EXECUTE PROCEDURE update_updated_at_timestamp();

-- Create debug function to list all tables
CREATE OR REPLACE FUNCTION get_all_tables()
RETURNS TABLE (table_name text) SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY SELECT tablename::text FROM pg_tables 
  WHERE schemaname = 'public';
END;
$$ LANGUAGE plpgsql;

-- Insert sample data for testing
INSERT INTO buses (id, route_name, driver_name, capacity, is_active)
VALUES 
  ('bus_1', 'Campus - Downtown', 'John Smith', 40, true),
  ('bus_2', 'Campus - North Area', 'Jane Doe', 35, true),
  ('bus_3', 'Campus - East Area', 'Robert Johnson', 40, true);

-- Set up realtime subscriptions
BEGIN;
  -- Enable publication for realtime
  DROP PUBLICATION IF EXISTS supabase_realtime;
  CREATE PUBLICATION supabase_realtime FOR TABLE bus_locations;
COMMIT; 