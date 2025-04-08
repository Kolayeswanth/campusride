-- Create trip_history table
CREATE TABLE IF NOT EXISTS public.trip_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  bus_id TEXT NOT NULL,
  route_id TEXT NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
  route_name TEXT NOT NULL,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS trip_history_driver_id_idx ON public.trip_history(driver_id);
CREATE INDEX IF NOT EXISTS trip_history_route_id_idx ON public.trip_history(route_id);
CREATE INDEX IF NOT EXISTS trip_history_start_time_idx ON public.trip_history(start_time);

-- Add RLS policies
ALTER TABLE public.trip_history ENABLE ROW LEVEL SECURITY;

-- Policy for drivers to view their own trip history
CREATE POLICY "Drivers can view their own trip history"
  ON public.trip_history
  FOR SELECT
  USING (auth.uid() = driver_id);

-- Policy for drivers to insert their own trip history
CREATE POLICY "Drivers can insert their own trip history"
  ON public.trip_history
  FOR INSERT
  WITH CHECK (auth.uid() = driver_id);

-- Policy for drivers to update their own trip history
CREATE POLICY "Drivers can update their own trip history"
  ON public.trip_history
  FOR UPDATE
  USING (auth.uid() = driver_id);

-- Policy for passengers to view trip history
CREATE POLICY "Passengers can view trip history"
  ON public.trip_history
  FOR SELECT
  USING (true); 