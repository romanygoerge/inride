-- Migration: Add otp_support_whatsapp to app_settings table
ALTER TABLE public.app_settings 
ADD COLUMN IF NOT EXISTS otp_support_whatsapp TEXT DEFAULT '01204062941';

-- Set default value for existing row
UPDATE public.app_settings 
SET otp_support_whatsapp = '01204062941' 
WHERE id = 'default' AND (otp_support_whatsapp IS NULL OR otp_support_whatsapp = '');
