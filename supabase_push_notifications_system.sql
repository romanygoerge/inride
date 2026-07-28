-- ====================================================================
-- SUPABASE COMPLETE PUSH NOTIFICATION & DEVICE TOKEN SYSTEM SCRIPT
-- Project: inRide App 2026
-- ====================================================================

-- 1. CREATE USER DEVICES TABLE (Multi-Device Push Token Management)
CREATE TABLE IF NOT EXISTS public.user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'android' CHECK (platform IN ('android', 'ios', 'web')),
    device_type TEXT DEFAULT 'phone',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_device_token UNIQUE (user_id, device_token)
);

-- Indexes for lightning fast token lookups
CREATE INDEX IF NOT EXISTS idx_user_devices_user_active ON public.user_devices(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_user_devices_token ON public.user_devices(device_token);

-- Enable RLS on user_devices
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own devices" ON public.user_devices;
DROP POLICY IF EXISTS "Users can insert own devices" ON public.user_devices;
DROP POLICY IF EXISTS "Users can update own devices" ON public.user_devices;
DROP POLICY IF EXISTS "Users can delete own devices" ON public.user_devices;

CREATE POLICY "Users can read own devices" ON public.user_devices
    FOR SELECT USING (auth.uid() = user_id OR auth.role() = 'anon' OR auth.role() = 'service_role');

CREATE POLICY "Users can insert own devices" ON public.user_devices
    FOR INSERT WITH CHECK (auth.uid() = user_id OR auth.role() = 'anon' OR auth.role() = 'service_role');

CREATE POLICY "Users can update own devices" ON public.user_devices
    FOR UPDATE USING (auth.uid() = user_id OR auth.role() = 'anon' OR auth.role() = 'service_role');

CREATE POLICY "Users can delete own devices" ON public.user_devices
    FOR DELETE USING (auth.uid() = user_id OR auth.role() = 'anon' OR auth.role() = 'service_role');

-- 2. ENSURE NOTIFICATIONS TABLE EXISTS WITH CORRECT SCHEMA & RLS
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'info',
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id, created_at DESC);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Public insert notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users update own notifications" ON public.notifications;

CREATE POLICY "Users read own notifications" ON public.notifications FOR SELECT USING (true);
CREATE POLICY "Public insert notifications" ON public.notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "Users update own notifications" ON public.notifications FOR UPDATE USING (true);

-- Enable Replica Identity for Supabase Realtime
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- 3. RIDE REQUEST STATUS AUTOMATED NOTIFICATION TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION public.handle_ride_request_push_notification()
RETURNS TRIGGER AS $$
DECLARE
    notif_title TEXT;
    notif_body TEXT;
    notif_type TEXT;
    recipient_id UUID;
BEGIN
    -- Handle New Ride Request Created (Insert with Pending)
    IF (TG_OP = 'INSERT') THEN
        IF NEW.status = 'Pending' THEN
            -- We insert notification record for passenger confirming request
            recipient_id := NEW.passenger_id;
            notif_title := 'تم تقديم طلب الرحلة 🚗';
            notif_body := 'جاري البحث عن كابتن قريب لنقل طلبك...';
            notif_type := 'new_ride_created';

            INSERT INTO public.notifications (user_id, title, body, type, is_read, data, created_at)
            VALUES (
                recipient_id,
                notif_title,
                notif_body,
                notif_type,
                false,
                jsonb_build_object('requestId', NEW.id, 'ride_id', NEW.id, 'status', NEW.status, 'action', 'view_ride'),
                NOW()
            );
            RETURN NEW;
        END IF;
    ELSIF (TG_OP = 'UPDATE') THEN
        IF NEW.status = OLD.status THEN
            RETURN NEW;
        END IF;

        IF NEW.status = 'Accepted' THEN
            recipient_id := NEW.passenger_id;
            notif_title := 'تم قبول طلب الرحلة 🎉';
            notif_body := 'وافق الكابتن على رحلتك وهو في الطريق إليك الآن.';
            notif_type := 'accept_trip';

        ELSIF NEW.status = 'DriverArriving' OR NEW.status = 'Arrived' THEN
            recipient_id := NEW.passenger_id;
            notif_title := 'الكابتن وصل 📍';
            notif_body := 'كابتن الرحلة وصل إلى نقطة الاستلام وهو بانتظارك.';
            notif_type := 'driver_arrived';

        ELSIF NEW.status = 'TripStarted' THEN
            recipient_id := NEW.passenger_id;
            notif_title := 'بدأت الرحلة 🚀';
            notif_body := 'رحلتك بدأت الآن مع الكابتن. نتمنى لك رحلة سعيدة وآمنة.';
            notif_type := 'trip_started';

        ELSIF NEW.status = 'Completed' THEN
            recipient_id := NEW.passenger_id;
            notif_title := 'اكتملت الرحلة 🏁';
            notif_body := 'تم إنهاء الرحلة بنجاح. شكراً لاستخدامك inRide.';
            notif_type := 'trip_completed';

        ELSIF NEW.status = 'Cancelled' THEN
            IF NEW.cancelled_by = 'driver' THEN
                recipient_id := NEW.passenger_id;
                notif_body := 'قام الكابتن بإلغاء الرحلة.';
            ELSE
                recipient_id := NEW.driver_id;
                notif_body := 'قام الراكب بإلغاء الرحلة.';
            END IF;

            IF recipient_id IS NOT NULL THEN
                notif_title := 'تم إلغاء الرحلة ❌';
                notif_type := 'cancel_trip';
            END IF;
        END IF;

        IF recipient_id IS NOT NULL THEN
            INSERT INTO public.notifications (user_id, title, body, type, is_read, data, created_at)
            VALUES (
                recipient_id,
                notif_title,
                notif_body,
                notif_type,
                false,
                jsonb_build_object('requestId', NEW.id, 'ride_id', NEW.id, 'status', NEW.status, 'sender_id', auth.uid(), 'receiver_id', recipient_id, 'action', 'view_ride'),
                NOW()
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_ride_request_push_notification ON public.ride_requests;
CREATE TRIGGER trg_ride_request_push_notification
    AFTER INSERT OR UPDATE ON public.ride_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_ride_request_push_notification();

-- 4. RIDE OFFER AUTOMATED NOTIFICATION TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION public.handle_ride_offer_push_notification()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO public.notifications (user_id, title, body, type, is_read, data, created_at)
        VALUES (
            NEW.passenger_id,
            'عرض جديد من كابتن 🏷️',
            'قدّم الكابتن ' || COALESCE(NEW.driver_name, 'سائق') || ' عرضاً بقيمة ' || NEW.price || ' د.أ',
            'new_offer',
            false,
            jsonb_build_object(
                'offerId', NEW.id,
                'requestId', NEW.request_id,
                'ride_id', NEW.request_id,
                'driverId', NEW.driver_id,
                'sender_id', NEW.driver_id,
                'receiver_id', NEW.passenger_id,
                'price', NEW.price,
                'action', 'view_offers'
            ),
            NOW()
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_ride_offer_push_notification ON public.ride_offers;
CREATE TRIGGER trg_ride_offer_push_notification
    AFTER INSERT ON public.ride_offers
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_ride_offer_push_notification();

-- 5. CHAT MESSAGE AUTOMATED NOTIFICATION TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION public.handle_chat_message_push_notification()
RETURNS TRIGGER AS $$
DECLARE
    req_passenger UUID;
    req_driver UUID;
    recipient_id UUID;
    sender_name TEXT;
BEGIN
    SELECT passenger_id, driver_id INTO req_passenger, req_driver
    FROM public.ride_requests
    WHERE id = NEW.request_id;

    IF NEW.sender_id = req_passenger THEN
        recipient_id := req_driver;
    ELSE
        recipient_id := req_passenger;
    END IF;

    SELECT name INTO sender_name FROM public.users WHERE id = NEW.sender_id;
    IF sender_name IS NULL THEN
        sender_name := 'مستخدم';
    END IF;

    IF recipient_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, is_read, data, created_at)
        VALUES (
            recipient_id,
            'رسالة جديدة من ' || sender_name || ' 💬',
            NEW.text,
            'chat_message',
            false,
            jsonb_build_object(
                'id', NEW.id,
                'tripId', NEW.request_id,
                'ride_id', NEW.request_id,
                'partnerId', NEW.sender_id,
                'sender_id', NEW.sender_id,
                'receiver_id', recipient_id,
                'partnerName', sender_name,
                'action', 'open_chat'
            ),
            NOW()
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_chat_message_push_notification ON public.chat_messages;
CREATE TRIGGER trg_chat_message_push_notification
    AFTER INSERT ON public.chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_chat_message_push_notification();
