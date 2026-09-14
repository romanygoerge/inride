-- ====================================================================
-- INRIDE PRODUCTION SECURITY AUDIT REMEDIATION SCRIPT (2026)
-- Resolves:
-- 1. Table for secure server-side OTP requests with rate-limiting & hash
-- 2. Eliminates all vulnerable "USING (true)", "WITH CHECK (true)", and "OR true" RLS bypasses
-- 3. Locks down user_devices, messages, chat_rooms, support_chats, support_messages
-- 4. Enforces strict principle of least privilege across all user data
-- ====================================================================

-- --------------------------------------------------------------------
-- 1. Secure Server-Side OTP Requests Table
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.otp_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number TEXT NOT NULL,
    otp_hash TEXT NOT NULL,
    attempts INT NOT NULL DEFAULT 0,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_otp_requests_phone_created ON public.otp_requests(phone_number, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_otp_requests_expiry ON public.otp_requests(expires_at);

-- Lock down completely from public/authenticated access; accessed solely by server service_role
ALTER TABLE public.otp_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Deny all public access to otp_requests" ON public.otp_requests;
DROP POLICY IF EXISTS "Allow service_role full access to otp_requests" ON public.otp_requests;

CREATE POLICY "Allow service_role full access to otp_requests"
ON public.otp_requests
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- --------------------------------------------------------------------
-- 2. Clean Up Open Policies on Messages, Chats, and Support
-- --------------------------------------------------------------------

-- 2.1 Chat Rooms
ALTER TABLE IF EXISTS public.chat_rooms ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users view their own chat rooms" ON public.chat_rooms;
DROP POLICY IF EXISTS "Allow open chat_rooms access" ON public.chat_rooms;
DROP POLICY IF EXISTS "Public chat_rooms read" ON public.chat_rooms;

CREATE POLICY "Users access own chat rooms or admin"
ON public.chat_rooms
FOR ALL
TO authenticated
USING (
    (auth.uid() IS NOT NULL AND (passenger_id = auth.uid() OR driver_id = auth.uid()))
    OR public.is_admin()
    OR public.is_active_admin()
)
WITH CHECK (
    (auth.uid() IS NOT NULL AND (passenger_id = auth.uid() OR driver_id = auth.uid()))
    OR public.is_admin()
    OR public.is_active_admin()
);

-- 2.2 Messages
ALTER TABLE IF EXISTS public.messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users access messages in their rooms" ON public.messages;
DROP POLICY IF EXISTS "Allow open messages access" ON public.messages;
DROP POLICY IF EXISTS "Public messages read" ON public.messages;

CREATE POLICY "Users access messages in their rooms or admin"
ON public.messages
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.chat_rooms r
        WHERE r.id = messages.room_id AND (r.passenger_id = auth.uid() OR r.driver_id = auth.uid())
    )
    OR public.is_admin()
    OR public.is_active_admin()
);

CREATE POLICY "Users insert messages in their rooms or admin"
ON public.messages
FOR INSERT
TO authenticated
WITH CHECK (
    (
        auth.uid() = sender_id AND
        EXISTS (
            SELECT 1 FROM public.chat_rooms r
            WHERE r.id = messages.room_id AND (r.passenger_id = auth.uid() OR r.driver_id = auth.uid())
        )
    )
    OR public.is_admin()
    OR public.is_active_admin()
);

CREATE POLICY "Users update own messages or admin"
ON public.messages
FOR UPDATE
TO authenticated
USING (
    auth.uid() = sender_id OR public.is_admin() OR public.is_active_admin()
)
WITH CHECK (
    auth.uid() = sender_id OR public.is_admin() OR public.is_active_admin()
);

-- 2.3 Message Reads
ALTER TABLE IF EXISTS public.message_reads ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users access message reads in their rooms" ON public.message_reads;

CREATE POLICY "Users access message reads in their rooms or admin"
ON public.message_reads
FOR ALL
TO authenticated
USING (
    auth.uid() = user_id
    OR EXISTS (
        SELECT 1 FROM public.messages m
        JOIN public.chat_rooms r ON m.room_id = r.id
        WHERE m.id = message_reads.message_id AND (r.passenger_id = auth.uid() OR r.driver_id = auth.uid())
    )
    OR public.is_admin()
    OR public.is_active_admin()
);

-- 2.4 Attachments
ALTER TABLE IF EXISTS public.attachments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users access attachments in their rooms" ON public.attachments;

CREATE POLICY "Users access attachments in their rooms or admin"
ON public.attachments
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.messages m
        JOIN public.chat_rooms r ON m.room_id = r.id
        WHERE m.id = attachments.message_id AND (r.passenger_id = auth.uid() OR r.driver_id = auth.uid())
    )
    OR public.is_admin()
    OR public.is_active_admin()
);

-- 2.5 Support Chats
ALTER TABLE IF EXISTS public.support_chats ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow full support_chats access" ON public.support_chats;
DROP POLICY IF EXISTS "Allow open support_chats" ON public.support_chats;
DROP POLICY IF EXISTS "Support chats policy" ON public.support_chats;

CREATE POLICY "Users and admins access support chats"
ON public.support_chats
FOR ALL
TO authenticated
USING (
    auth.uid() = user_id OR public.is_admin() OR public.is_active_admin()
)
WITH CHECK (
    auth.uid() = user_id OR public.is_admin() OR public.is_active_admin()
);

-- 2.6 Support Messages
ALTER TABLE IF EXISTS public.support_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow full support_messages access" ON public.support_messages;
DROP POLICY IF EXISTS "Allow open support_messages" ON public.support_messages;

CREATE POLICY "Users and admins read support messages"
ON public.support_messages
FOR SELECT
TO authenticated
USING (
    auth.uid() = user_id OR sender_id = auth.uid() OR public.is_admin() OR public.is_active_admin()
);

CREATE POLICY "Users and admins insert support messages"
ON public.support_messages
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id OR sender_id = auth.uid() OR public.is_admin() OR public.is_active_admin()
);

CREATE POLICY "Users and admins update support messages"
ON public.support_messages
FOR UPDATE
TO authenticated
USING (
    auth.uid() = user_id OR sender_id = auth.uid() OR public.is_admin() OR public.is_active_admin()
);

-- 2.7 Support Tickets
ALTER TABLE IF EXISTS public.support_tickets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users access their own support tickets" ON public.support_tickets;

CREATE POLICY "Users access their own support tickets or admin"
ON public.support_tickets
FOR ALL
TO authenticated
USING (
    auth.uid() = user_id OR public.is_admin() OR public.is_active_admin()
);

-- --------------------------------------------------------------------
-- 3. Clean Up Open Policies on Notifications & User Devices
-- --------------------------------------------------------------------

-- 3.1 User Devices
ALTER TABLE IF EXISTS public.user_devices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public user_devices access" ON public.user_devices;
DROP POLICY IF EXISTS "Users manage own devices" ON public.user_devices;

CREATE POLICY "Users manage own devices"
ON public.user_devices
FOR ALL
TO authenticated
USING (
    auth.uid() = user_id OR public.is_admin() OR public.is_active_admin()
)
WITH CHECK (
    auth.uid() = user_id OR public.is_admin() OR public.is_active_admin()
);

-- 3.2 Notifications
ALTER TABLE IF EXISTS public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public insert notifications" ON public.notifications;
DROP POLICY IF EXISTS "Public notifications full access" ON public.notifications;
DROP POLICY IF EXISTS "Users read own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users update own notifications" ON public.notifications;

CREATE POLICY "Users read own notifications"
ON public.notifications
FOR SELECT
TO authenticated
USING (
    auth.uid() = user_id OR public.is_admin() OR public.is_active_admin()
);

CREATE POLICY "Users update own notifications"
ON public.notifications
FOR UPDATE
TO authenticated
USING (
    auth.uid() = user_id OR public.is_admin() OR public.is_active_admin()
)
WITH CHECK (
    auth.uid() = user_id OR public.is_admin() OR public.is_active_admin()
);

CREATE POLICY "System and admins insert notifications"
ON public.notifications
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id OR public.is_admin() OR public.is_active_admin()
);

-- 3.3 Admin Notifications
ALTER TABLE IF EXISTS public.admin_notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow open admin_notifications access" ON public.admin_notifications;

CREATE POLICY "Only admins access admin_notifications"
ON public.admin_notifications
FOR ALL
TO authenticated
USING (
    public.is_admin() OR public.is_active_admin()
)
WITH CHECK (
    public.is_admin() OR public.is_active_admin()
);

-- --------------------------------------------------------------------
-- 4. Clean Up Open Policies on Users, Passengers, Wallets, Trips
-- --------------------------------------------------------------------

-- 4.1 Users Table Open Policies Cleanup
ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow open users access" ON public.users;
DROP POLICY IF EXISTS "Public users read access" ON public.users;
DROP POLICY IF EXISTS "Allow authenticated read users" ON public.users;
DROP POLICY IF EXISTS "Allow authenticated insert users" ON public.users;
DROP POLICY IF EXISTS "Users read own profile or admin" ON public.users;
DROP POLICY IF EXISTS "Users insert own profile or admin" ON public.users;
DROP POLICY IF EXISTS "Users update own profile or admin" ON public.users;

CREATE POLICY "Users read own profile or admin"
ON public.users
FOR SELECT
TO authenticated
USING (
    auth.uid() = id OR public.is_admin() OR public.is_active_admin()
);

CREATE POLICY "Users insert own profile or admin"
ON public.users
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = id OR public.is_admin() OR public.is_active_admin()
);

CREATE POLICY "Users update own profile or admin"
ON public.users
FOR UPDATE
TO authenticated
USING (
    auth.uid() = id OR public.is_admin() OR public.is_active_admin()
)
WITH CHECK (
    auth.uid() = id OR public.is_admin() OR public.is_active_admin()
);

-- 4.2 Passengers Table Open Policies Cleanup
ALTER TABLE IF EXISTS public.passengers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow open passengers access" ON public.passengers;
DROP POLICY IF EXISTS "Public passengers read" ON public.passengers;

-- 4.3 Wallets Table Open Policies Cleanup
ALTER TABLE IF EXISTS public.wallets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow open wallets access" ON public.wallets;

CREATE POLICY "Users view own wallet or admin"
ON public.wallets
FOR SELECT
TO authenticated
USING (
    auth.uid() = user_id OR public.is_admin() OR public.is_active_admin()
);

-- 4.4 Trips Table Open Policies Cleanup
ALTER TABLE IF EXISTS public.trips ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow open trips access" ON public.trips;

CREATE POLICY "Participants view trips or admin"
ON public.trips
FOR SELECT
TO authenticated
USING (
    auth.uid() = passenger_id OR auth.uid() = driver_id OR public.is_admin() OR public.is_active_admin()
);

CREATE POLICY "Participants update trips or admin"
ON public.trips
FOR UPDATE
TO authenticated
USING (
    auth.uid() = passenger_id OR auth.uid() = driver_id OR public.is_admin() OR public.is_active_admin()
);

-- 4.5 Ride Requests Table Open Policies Cleanup
ALTER TABLE IF EXISTS public.ride_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow open ride_requests access" ON public.ride_requests;
DROP POLICY IF EXISTS "Public ride_requests full access" ON public.ride_requests;
DROP POLICY IF EXISTS "Public ride_requests read" ON public.ride_requests;
DROP POLICY IF EXISTS "Participants and nearby drivers read ride_requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Active Admins full access to ride_requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Users read relevant ride_requests" ON public.ride_requests;

CREATE POLICY "Active Admins full access to ride_requests"
ON public.ride_requests
FOR ALL
TO authenticated
USING (
    public.is_admin() OR public.is_active_admin()
)
WITH CHECK (
    public.is_admin() OR public.is_active_admin()
);

CREATE POLICY "Users read relevant ride_requests"
ON public.ride_requests
FOR SELECT
TO authenticated
USING (
    passenger_id = auth.uid()
    OR driver_id = auth.uid()
    OR driver_id IS NULL
    OR lower(status) IN ('pending', 'searching')
    OR public.is_admin()
    OR public.is_active_admin()
);

CREATE POLICY "Passengers insert own ride_requests"
ON public.ride_requests
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = passenger_id OR public.is_admin() OR public.is_active_admin()
);

CREATE POLICY "Participants and admins update ride_requests"
ON public.ride_requests
FOR UPDATE
TO authenticated
USING (
    auth.uid() = passenger_id OR auth.uid() = driver_id OR public.is_admin() OR public.is_active_admin()
);
