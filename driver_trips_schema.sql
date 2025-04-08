-- Create driver_trips table for storing trip data
CREATE TABLE IF NOT EXISTS driver_trips (
  id TEXT PRIMARY KEY,
  driver_id UUID REFERENCES auth.users(id),
  bus_id TEXT REFERENCES buses(id),
  route_name TEXT NOT NULL,
  start_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  end_time TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Enable RLS on driver_trips table
ALTER TABLE driver_trips ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Drivers can insert their own trips" ON driver_trips;
DROP POLICY IF EXISTS "Drivers can update their own trips" ON driver_trips;
DROP POLICY IF EXISTS "Drivers can read their own trips" ON driver_trips;
DROP POLICY IF EXISTS "Passengers can read active trips" ON driver_trips;

-- Create policies for driver_trips table
-- Allow drivers to insert their own trips
CREATE POLICY "Drivers can insert their own trips"
  ON driver_trips FOR INSERT
  WITH CHECK (auth.uid() = driver_id);

-- Allow drivers to update their own trips
CREATE POLICY "Drivers can update their own trips"
  ON driver_trips FOR UPDATE
  USING (auth.uid() = driver_id);

-- Allow drivers to read their own trips
CREATE POLICY "Drivers can read their own trips"
  ON driver_trips FOR SELECT
  USING (auth.uid() = driver_id);

-- Allow passengers to read active trips (for bus tracking)
CREATE POLICY "Passengers can read active trips"
  ON driver_trips FOR SELECT
  USING (is_active = true);

-- Update realtime publication to include driver_trips for real-time updates
BEGIN;
  ALTER PUBLICATION supabase_realtime ADD TABLE driver_trips;
COMMIT; 