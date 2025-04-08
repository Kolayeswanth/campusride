-- Enable necessary extensions
create extension if not exists "uuid-ossp";
create extension if not exists "postgis";

-- Create user profiles table
create table if not exists public.user_profiles (
    id uuid references auth.users on delete cascade primary key,
    email text unique not null,
    role text not null check (role in ('driver', 'passenger')),
    name text,
    avatar_url text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create user locations table
create table if not exists public.user_locations (
    id uuid default uuid_generate_v4() primary key,
    user_id uuid references public.user_profiles on delete cascade not null,
    role text not null check (role in ('driver', 'passenger')),
    latitude double precision not null,
    longitude double precision not null,
    accuracy double precision,
    speed double precision,
    heading double precision,
    timestamp timestamp with time zone default timezone('utc'::text, now()) not null,
    location geometry(Point, 4326) generated always as (st_setsrid(st_makepoint(longitude, latitude), 4326)) stored
);

-- Create trips table
create table if not exists public.trips (
    id uuid default uuid_generate_v4() primary key,
    driver_id uuid references public.user_profiles on delete cascade not null,
    status text not null check (status in ('scheduled', 'in_progress', 'completed', 'cancelled')),
    start_location geometry(Point, 4326) not null,
    end_location geometry(Point, 4326) not null,
    route geometry(LineString, 4326),
    scheduled_start_time timestamp with time zone not null,
    actual_start_time timestamp with time zone,
    end_time timestamp with time zone,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create trip locations table for tracking
create table if not exists public.trip_locations (
    id uuid default uuid_generate_v4() primary key,
    trip_id uuid references public.trips on delete cascade not null,
    latitude double precision not null,
    longitude double precision not null,
    accuracy double precision,
    speed double precision,
    heading double precision,
    timestamp timestamp with time zone default timezone('utc'::text, now()) not null,
    location geometry(Point, 4326) generated always as (st_setsrid(st_makepoint(longitude, latitude), 4326)) stored
);

-- Create favorite routes table
create table if not exists public.favorite_routes (
    id uuid default uuid_generate_v4() primary key,
    user_id uuid references public.user_profiles on delete cascade not null,
    name text not null,
    start_location geometry(Point, 4326) not null,
    end_location geometry(Point, 4326) not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create notifications table
create table if not exists public.notifications (
    id uuid default uuid_generate_v4() primary key,
    user_id uuid references public.user_profiles on delete cascade not null,
    title text not null,
    message text not null,
    type text not null check (type in ('info', 'warning', 'error', 'success')),
    read boolean default false not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create RLS policies
alter table public.user_profiles enable row level security;
alter table public.user_locations enable row level security;
alter table public.trips enable row level security;
alter table public.trip_locations enable row level security;
alter table public.favorite_routes enable row level security;
alter table public.notifications enable row level security;

-- User profiles policies
create policy "Users can view their own profile"
    on public.user_profiles for select
    using (auth.uid() = id);

create policy "Users can update their own profile"
    on public.user_profiles for update
    using (auth.uid() = id);

-- User locations policies
create policy "Anyone can view user locations"
    on public.user_locations for select
    using (true);

create policy "Users can update their own location"
    on public.user_locations for insert
    with check (auth.uid() = user_id);

create policy "Users can update their own location"
    on public.user_locations for update
    using (auth.uid() = user_id);

-- Trips policies
create policy "Anyone can view trips"
    on public.trips for select
    using (true);

create policy "Drivers can create trips"
    on public.trips for insert
    with check (
        auth.uid() = driver_id
        and exists (
            select 1 from public.user_profiles
            where id = auth.uid()
            and role = 'driver'
        )
    );

create policy "Drivers can update their own trips"
    on public.trips for update
    using (auth.uid() = driver_id);

-- Trip locations policies
create policy "Anyone can view trip locations"
    on public.trip_locations for select
    using (true);

create policy "Drivers can update trip locations"
    on public.trip_locations for insert
    with check (
        exists (
            select 1 from public.trips
            where id = trip_id
            and driver_id = auth.uid()
        )
    );

-- Favorite routes policies
create policy "Users can view their own favorite routes"
    on public.favorite_routes for select
    using (auth.uid() = user_id);

create policy "Users can create favorite routes"
    on public.favorite_routes for insert
    with check (auth.uid() = user_id);

create policy "Users can update their own favorite routes"
    on public.favorite_routes for update
    using (auth.uid() = user_id);

create policy "Users can delete their own favorite routes"
    on public.favorite_routes for delete
    using (auth.uid() = user_id);

-- Notifications policies
create policy "Users can view their own notifications"
    on public.notifications for select
    using (auth.uid() = user_id);

create policy "System can create notifications"
    on public.notifications for insert
    with check (true);

create policy "Users can update their own notifications"
    on public.notifications for update
    using (auth.uid() = user_id);

-- Create indexes
create index if not exists user_locations_user_id_idx on public.user_locations(user_id);
create index if not exists user_locations_role_idx on public.user_locations(role);
create index if not exists user_locations_timestamp_idx on public.user_locations(timestamp);
create index if not exists trips_driver_id_idx on public.trips(driver_id);
create index if not exists trips_status_idx on public.trips(status);
create index if not exists trip_locations_trip_id_idx on public.trip_locations(trip_id);
create index if not exists trip_locations_timestamp_idx on public.trip_locations(timestamp);
create index if not exists favorite_routes_user_id_idx on public.favorite_routes(user_id);
create index if not exists notifications_user_id_idx on public.notifications(user_id);
create index if not exists notifications_read_idx on public.notifications(read);

-- Create functions
create or replace function public.handle_new_user()
returns trigger as $$
begin
    insert into public.user_profiles (id, email, role)
    values (new.id, new.email, 'passenger');
    return new;
end;
$$ language plpgsql security definer;

-- Create triggers
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user(); 