-- One-time operator action after the first admin has signed up and
-- completed email OTP verification in EduNivora.
-- Replace the placeholder with the exact verified email address before running.
BEGIN;

DO $$
DECLARE
  target_email TEXT := lower(trim('REPLACE_WITH_VERIFIED_ADMIN_EMAIL'));
  target_id UUID;
  target_name TEXT;
BEGIN
  IF target_email = '' OR target_email LIKE '%REPLACE_WITH_%' THEN
    RAISE EXCEPTION 'Replace the admin email placeholder before running this script';
  END IF;

  IF EXISTS (SELECT 1 FROM public.app_users WHERE role = 'admin') THEN
    RAISE EXCEPTION 'An administrator already exists; refusing first-admin bootstrap';
  END IF;

  SELECT id, name
    INTO STRICT target_id, target_name
    FROM neon_auth."user"
   WHERE lower(email) = target_email
     AND "emailVerified" IS TRUE
     AND banned IS NOT TRUE;

  INSERT INTO public.app_users (auth_subject, display_name, email, role)
  SELECT target_id,
         left(coalesce(nullif(trim(target_name), ''), target_email), 120),
         target_email,
         'admin'
  ON CONFLICT (auth_subject) DO UPDATE
    SET role = 'admin',
        updated_at = NOW();

  RAISE NOTICE 'First administrator role assigned to %', target_email;
END
$$;

COMMIT;
