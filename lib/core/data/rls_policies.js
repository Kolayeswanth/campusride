[
    {
      "table_name": "bus_locations",
      "policy_name": "Public read access for bus_locations",
      "permissive": "PERMISSIVE",
      "command": "SELECT",
      "roles": "{public}",
      "using_expression": "true",
      "check_expression": null
    },
    {
      "table_name": "buses",
      "policy_name": "Public read access for buses",
      "permissive": "PERMISSIVE",
      "command": "SELECT",
      "roles": "{public}",
      "using_expression": "true",
      "check_expression": null
    },
    {
      "table_name": "colleges",
      "policy_name": "colleges_select_public",
      "permissive": "PERMISSIVE",
      "command": "SELECT",
      "roles": "{public}",
      "using_expression": "true",
      "check_expression": null
    },
    {
      "table_name": "driver_requests",
      "policy_name": "driver_requests_admin_all",
      "permissive": "PERMISSIVE",
      "command": "ALL",
      "roles": "{public}",
      "using_expression": "(EXISTS ( SELECT 1\n   FROM profiles\n  WHERE ((profiles.id = auth.uid()) AND ((profiles.role = 'admin'::text) OR (profiles.role = 'super_admin'::text)))))",
      "check_expression": null
    },
    {
      "table_name": "driver_requests",
      "policy_name": "driver_requests_insert_own",
      "permissive": "PERMISSIVE",
      "command": "INSERT",
      "roles": "{public}",
      "using_expression": null,
      "check_expression": "(auth.uid() = user_id)"
    },
    {
      "table_name": "driver_requests",
      "policy_name": "driver_requests_select_own",
      "permissive": "PERMISSIVE",
      "command": "SELECT",
      "roles": "{public}",
      "using_expression": "(auth.uid() = user_id)",
      "check_expression": null
    },
    {
      "table_name": "driver_trip_locations",
      "policy_name": "Allow reading locations for active trips",
      "permissive": "PERMISSIVE",
      "command": "SELECT",
      "roles": "{public}",
      "using_expression": "(EXISTS ( SELECT 1\n   FROM driver_trips\n  WHERE ((driver_trips.id = driver_trip_locations.trip_id) AND ((driver_trips.status)::text = 'active'::text))))",
      "check_expression": null
    },
    {
      "table_name": "driver_trip_locations",
      "policy_name": "Drivers can insert their locations",
      "permissive": "PERMISSIVE",
      "command": "INSERT",
      "roles": "{public}",
      "using_expression": null,
      "check_expression": "(EXISTS ( SELECT 1\n   FROM driver_trips\n  WHERE ((driver_trips.id = driver_trip_locations.trip_id) AND (driver_trips.driver_id = auth.uid()))))"
    },
    {
      "table_name": "driver_trip_locations",
      "policy_name": "Drivers can manage their trip locations",
      "permissive": "PERMISSIVE",
      "command": "ALL",
      "roles": "{public}",
      "using_expression": "(EXISTS ( SELECT 1\n   FROM driver_trips\n  WHERE ((driver_trips.id = driver_trip_locations.trip_id) AND (driver_trips.driver_id = auth.uid()))))",
      "check_expression": null
    },
    {
      "table_name": "driver_trip_polylines",
      "policy_name": "Drivers can manage their trip polylines",
      "permissive": "PERMISSIVE",
      "command": "ALL",
      "roles": "{public}",
      "using_expression": "(EXISTS ( SELECT 1\n   FROM driver_trips\n  WHERE ((driver_trips.id = driver_trip_polylines.trip_id) AND (driver_trips.driver_id = auth.uid()))))",
      "check_expression": null
    },
    {
      "table_name": "driver_trips",
      "policy_name": "Allow reading active trips for passenger tracking",
      "permissive": "PERMISSIVE",
      "command": "SELECT",
      "roles": "{public}",
      "using_expression": "((status)::text = 'active'::text)",
      "check_expression": null
    },
    {
      "table_name": "driver_trips",
      "policy_name": "Drivers can create their own trips",
      "permissive": "PERMISSIVE",
      "command": "INSERT",
      "roles": "{public}",
      "using_expression": null,
      "check_expression": "(auth.uid() = driver_id)"
    },
    {
      "table_name": "driver_trips",
      "policy_name": "Drivers can manage their own trips",
      "permissive": "PERMISSIVE",
      "command": "ALL",
      "roles": "{public}",
      "using_expression": "(auth.uid() = driver_id)",
      "check_expression": null
    },
    {
      "table_name": "driver_trips",
      "policy_name": "Drivers can update their own trips",
      "permissive": "PERMISSIVE",
      "command": "UPDATE",
      "roles": "{public}",
      "using_expression": "(auth.uid() = driver_id)",
      "check_expression": null
    },
    {
      "table_name": "driver_trips",
      "policy_name": "Drivers can view their own trips",
      "permissive": "PERMISSIVE",
      "command": "SELECT",
      "roles": "{public}",
      "using_expression": "(auth.uid() = driver_id)",
      "check_expression": null
    },
    {
      "table_name": "drivers",
      "policy_name": "drivers_admin_all",
      "permissive": "PERMISSIVE",
      "command": "ALL",
      "roles": "{public}",
      "using_expression": "(EXISTS ( SELECT 1\n   FROM profiles\n  WHERE ((profiles.id = auth.uid()) AND ((profiles.role = 'admin'::text) OR (profiles.role = 'super_admin'::text)))))",
      "check_expression": null
    },
    {
      "table_name": "drivers",
      "policy_name": "drivers_select_college",
      "permissive": "PERMISSIVE",
      "command": "SELECT",
      "roles": "{public}",
      "using_expression": "((college_id IN ( SELECT profiles.college_id\n   FROM profiles\n  WHERE (profiles.id = auth.uid()))) OR (EXISTS ( SELECT 1\n   FROM profiles\n  WHERE ((profiles.id = auth.uid()) AND ((profiles.role = 'admin'::text) OR (profiles.role = 'super_admin'::text))))))",
      "check_expression": null
    },
    {
      "table_name": "favorite_routes",
      "policy_name": "Users can delete their own favorite routes",
      "permissive": "PERMISSIVE",
      "command": "DELETE",
      "roles": "{authenticated}",
      "using_expression": "(user_id = auth.uid())",
      "check_expression": null
    },
    {
      "table_name": "favorite_routes",
      "policy_name": "Users can insert their own favorite routes",
      "permissive": "PERMISSIVE",
      "command": "INSERT",
      "roles": "{authenticated}",
      "using_expression": null,
      "check_expression": "(user_id = auth.uid())"
    },
    {
      "table_name": "favorite_routes",
      "policy_name": "Users can view their own favorite routes",
      "permissive": "PERMISSIVE",
      "command": "SELECT",
      "roles": "{authenticated}",
      "using_expression": "(user_id = auth.uid())",
      "check_expression": null
    },
    {
      "table_name": "profiles",
      "policy_name": "Users can insert their own profile",
      "permissive": "PERMISSIVE",
      "command": "INSERT",
      "roles": "{public}",
      "using_expression": null,
      "check_expression": "(auth.uid() = id)"
    },
    {
      "table_name": "profiles",
      "policy_name": "Users can update their own profile",
      "permissive": "PERMISSIVE",
      "command": "UPDATE",
      "roles": "{public}",
      "using_expression": "(auth.uid() = id)",
      "check_expression": null
    },
    {
      "table_name": "profiles",
      "policy_name": "Users can view their own profile",
      "permissive": "PERMISSIVE",
      "command": "SELECT",
      "roles": "{public}",
      "using_expression": "(auth.uid() = id)",
      "check_expression": null
    },
    {
      "table_name": "profiles",
      "policy_name": "profiles_insert_own",
      "permissive": "PERMISSIVE",
      "command": "INSERT",
      "roles": "{public}",
      "using_expression": null,
      "check_expression": "(auth.uid() = id)"
    },
    {
      "table_name": "profiles",
      "policy_name": "profiles_select_own",
      "permissive": "PERMISSIVE",
      "command": "SELECT",
      "roles": "{public}",
      "using_expression": "(auth.uid() = id)",
      "check_expression": null
    },
    {
      "table_name": "profiles",
      "policy_name": "profiles_update_own",
      "permissive": "PERMISSIVE",
      "command": "UPDATE",
      "roles": "{public}",
      "using_expression": "(auth.uid() = id)",
      "check_expression": "(auth.uid() = id)"
    },
    {
      "table_name": "routes",
      "policy_name": "routes_insert_policy",
      "permissive": "PERMISSIVE",
      "command": "INSERT",
      "roles": "{public}",
      "using_expression": null,
      "check_expression": "(auth.role() = 'authenticated'::text)"
    },
    {
      "table_name": "routes",
      "policy_name": "routes_select_policy",
      "permissive": "PERMISSIVE",
      "command": "SELECT",
      "roles": "{public}",
      "using_expression": "true",
      "check_expression": null
    },
    {
      "table_name": "routes",
      "policy_name": "routes_update_policy",
      "permissive": "PERMISSIVE",
      "command": "UPDATE",
      "roles": "{public}",
      "using_expression": "(auth.role() = 'authenticated'::text)",
      "check_expression": null
    },
    {
      "table_name": "user_locations",
      "policy_name": "Users can update their own location",
      "permissive": "PERMISSIVE",
      "command": "INSERT",
      "roles": "{authenticated}",
      "using_expression": null,
      "check_expression": "(user_id = auth.uid())"
    },
    {
      "table_name": "user_locations",
      "policy_name": "Users can view their own location",
      "permissive": "PERMISSIVE",
      "command": "SELECT",
      "roles": "{authenticated}",
      "using_expression": "(user_id = auth.uid())",
      "check_expression": null
    }
  ]