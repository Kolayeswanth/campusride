-- Drop existing insert policy if it exists
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.user_profiles;

-- Create new insert policy for user_profiles
CREATE POLICY "Users can insert their own profile"
    ON public.user_profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- Add a policy to allow initial profile creation during signup
CREATE POLICY "Allow initial profile creation"
    ON public.user_profiles FOR INSERT
    WITH CHECK (true); 