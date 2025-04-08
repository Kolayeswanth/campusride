-- Drop existing RLS policies for user_profiles table to start fresh
DROP POLICY IF EXISTS "Users can read their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;

-- Create a policy that allows anyone to insert a profile during sign-up
-- This is necessary because during registration, the user is authenticated but not yet fully setup
CREATE POLICY "Anyone can insert user profiles" 
  ON user_profiles FOR INSERT 
  TO authenticated
  WITH CHECK (true);

-- Allow users to read their own profile
CREATE POLICY "Users can read their own profile" 
  ON user_profiles FOR SELECT 
  USING (auth.uid() = id);

-- Allow users to update their own profile
CREATE POLICY "Users can update their own profile" 
  ON user_profiles FOR UPDATE 
  USING (auth.uid() = id);

-- Create a function to get all tables (for debugging)
CREATE OR REPLACE FUNCTION get_all_tables()
RETURNS TABLE (table_name text) SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY SELECT tablename::text FROM pg_tables 
  WHERE schemaname = 'public';
END;
$$ LANGUAGE plpgsql; 