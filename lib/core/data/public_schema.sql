-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.bus_locations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  bus_id uuid NOT NULL,
  schedule_id uuid,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  heading double precision,
  speed double precision,
  timestamp timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT bus_locations_pkey PRIMARY KEY (id),
  CONSTRAINT bus_locations_bus_id_fkey FOREIGN KEY (bus_id) REFERENCES public.buses(id)
);
CREATE TABLE public.buses (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  bus_number text NOT NULL UNIQUE,
  capacity integer NOT NULL,
  is_active boolean DEFAULT true,
  last_location_latitude double precision,
  last_location_longitude double precision,
  last_location_updated_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT buses_pkey PRIMARY KEY (id)
);
CREATE TABLE public.colleges (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  address text NOT NULL,
  code text NOT NULL UNIQUE,
  contact_phone text,
  contact_email text,
  logo_url text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone,
  location text,
  latitude double precision,
  longitude double precision,
  CONSTRAINT colleges_pkey PRIMARY KEY (id)
);
CREATE TABLE public.driver_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  college_id uuid,
  license_number text NOT NULL,
  driving_experience_years integer NOT NULL,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT driver_requests_pkey PRIMARY KEY (id),
  CONSTRAINT driver_requests_college_id_fkey FOREIGN KEY (college_id) REFERENCES public.colleges(id),
  CONSTRAINT driver_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.driver_trip_locations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  trip_id uuid,
  latitude numeric NOT NULL,
  longitude numeric NOT NULL,
  heading numeric,
  speed numeric,
  accuracy numeric,
  timestamp timestamp with time zone DEFAULT now(),
  is_on_route boolean DEFAULT true,
  distance_from_route numeric,
  CONSTRAINT driver_trip_locations_pkey PRIMARY KEY (id),
  CONSTRAINT driver_trip_locations_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.driver_trips(id)
);
CREATE TABLE public.driver_trip_polylines (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  trip_id uuid,
  polyline_data jsonb NOT NULL,
  segment_start_time timestamp with time zone DEFAULT now(),
  segment_end_time timestamp with time zone,
  is_deviation boolean DEFAULT false,
  merged_with_planned_route boolean DEFAULT false,
  CONSTRAINT driver_trip_polylines_pkey PRIMARY KEY (id),
  CONSTRAINT driver_trip_polylines_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.driver_trips(id)
);
CREATE TABLE public.driver_trips (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  driver_id uuid,
  route_id text,
  bus_number character varying,
  start_time timestamp with time zone DEFAULT now(),
  end_time timestamp with time zone,
  status character varying DEFAULT 'active'::character varying CHECK (status::text = ANY (ARRAY['active'::character varying, 'completed'::character varying, 'cancelled'::character varying]::text[])),
  start_location jsonb,
  end_location jsonb,
  actual_distance_km numeric,
  actual_duration_minutes integer,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT driver_trips_pkey PRIMARY KEY (id),
  CONSTRAINT driver_trips_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES auth.users(id)
);
CREATE TABLE public.drivers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE,
  college_id uuid NOT NULL,
  license_number text NOT NULL,
  driving_experience_years integer NOT NULL,
  is_active boolean DEFAULT true,
  total_trips integer DEFAULT 0,
  rating numeric DEFAULT 0.00,
  approved_at timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT drivers_pkey PRIMARY KEY (id),
  CONSTRAINT drivers_college_id_fkey FOREIGN KEY (college_id) REFERENCES public.colleges(id),
  CONSTRAINT drivers_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.favorite_routes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  route_id text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT favorite_routes_pkey PRIMARY KEY (id),
  CONSTRAINT favorite_routes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT favorite_routes_route_id_fkey FOREIGN KEY (route_id) REFERENCES public.routes(id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  email text NOT NULL UNIQUE,
  display_name text,
  photo_url text,
  role text NOT NULL DEFAULT 'user'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  college_id uuid,
  phone text,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_college_id_fkey FOREIGN KEY (college_id) REFERENCES public.colleges(id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.routes (
  id text NOT NULL,
  name text NOT NULL,
  start_location jsonb NOT NULL,
  end_location jsonb NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  polyline_data jsonb,
  estimated_duration_minutes integer,
  distance_km double precision,
  college_code text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT routes_pkey PRIMARY KEY (id),
  CONSTRAINT fk_college FOREIGN KEY (college_code) REFERENCES public.colleges(code)
);
CREATE TABLE public.spatial_ref_sys (
  srid integer NOT NULL CHECK (srid > 0 AND srid <= 998999),
  auth_name character varying,
  auth_srid integer,
  srtext character varying,
  proj4text character varying,
  CONSTRAINT spatial_ref_sys_pkey PRIMARY KEY (srid)
);
CREATE TABLE public.user_locations (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid,
  location USER-DEFINED NOT NULL,
  heading double precision,
  speed double precision,
  timestamp timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_locations_pkey PRIMARY KEY (id)
);