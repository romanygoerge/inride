-- ==============================================================================
-- InRide Production Data Reset Script
-- Safely clears all pre-launch test / k6 data while strictly preserving
-- Admin accounts, App settings, System configurations, Schema, RLS, and Triggers.
-- ==============================================================================

BEGIN;

-- 1. Attachments & Reads
DELETE FROM public.attachments;
DELETE FROM public.message_reads;

-- 2. Chat messages & Support
DELETE FROM public.messages;
DELETE FROM public.support_tickets;
DELETE FROM public.support_messages;
DELETE FROM public.support_chats;
DELETE FROM public.chat_rooms;
DELETE FROM public.chat_messages;
DELETE FROM public.typing_indicators;

-- 3. Ratings, Offers & Trips
DELETE FROM public.ratings;
DELETE FROM public.ride_offers;
DELETE FROM public.trips;
DELETE FROM public.ride_requests;

-- 4. Financials & Wallets
DELETE FROM public.financial_settlements;
DELETE FROM public.wallet_recharge_requests;
DELETE FROM public.transactions;
DELETE FROM public.wallets;

-- 5. Notifications & Devices
DELETE FROM public.admin_notification_receipts;
DELETE FROM public.admin_notifications;
DELETE FROM public.audit_logs;
DELETE FROM public.notifications;
DELETE FROM public.user_devices;

-- 6. Vehicles, Passengers & Drivers
DELETE FROM public.vehicles;
DELETE FROM public.passengers;
DELETE FROM public.drivers;

-- 7. Clean public.users (Preserve Super Admin)
DELETE FROM public.users
WHERE id != 'fbf9e43e-3ca0-4950-ab0e-11367a24c162'
  AND (email IS NULL OR email != 'romanygoerge48@gmail.com');

-- 8. Clean auth.users (Preserve Super Admin)
DELETE FROM auth.users
WHERE id != 'fbf9e43e-3ca0-4950-ab0e-11367a24c162'
  AND (email IS NULL OR email != 'romanygoerge48@gmail.com');

COMMIT;
