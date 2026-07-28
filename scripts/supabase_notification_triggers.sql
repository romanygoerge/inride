-- SQL Script: Automated Supabase Notification Triggers & Functions
-- Replaces old Firebase Cloud Messaging backend triggers with native Supabase logic

-- 1. Ensure Notifications table exists with correct schema
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'general',
    is_read BOOLEAN NOT NULL DEFAULT false,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id, created_at DESC);

-- Enable RLS and full access policies
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public notifications full access" ON public.notifications;
CREATE POLICY "Public notifications full access" ON public.notifications FOR ALL USING (true) WITH CHECK (true);

-- Enable Replica Identity for Realtime subscriptions
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- 2. Trigger Function for Ride Request Status Changes
CREATE OR REPLACE FUNCTION public.handle_ride_request_notification()
RETURNS TRIGGER AS $$
DECLARE
    notif_title TEXT;
    notif_body TEXT;
    notif_type TEXT;
    recipient_id UUID;
BEGIN
    -- Only trigger on INSERT (status='Pending') or status change
    IF (TG_OP = 'INSERT') THEN
        IF NEW.status = 'Pending' THEN
            -- Notification created when a new request is published
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
            notif_type := 'ride_accepted';

        ELSIF NEW.status = 'DriverArriving' OR NEW.status = 'Arrived' THEN
            recipient_id := NEW.passenger_id;
            notif_title := 'الكابتن وصل 📍';
            notif_body := 'كابتن الرحلة وصل إلى نقطة الاستلام وهو بانتظارك.';
            notif_type := 'captain_arrived';

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
            INSERT INTO public.notifications (
                user_id,
                title,
                body,
                type,
                is_read,
                data,
                created_at
            ) VALUES (
                recipient_id,
                notif_title,
                notif_body,
                notif_type,
                false,
                jsonb_build_object(
                    'requestId', NEW.id,
                    'tripId', NEW.id,
                    'status', NEW.status
                ),
                NOW()
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop and re-create trigger on ride_requests
DROP TRIGGER IF EXISTS trg_ride_request_notification ON public.ride_requests;
CREATE TRIGGER trg_ride_request_notification
    AFTER INSERT OR UPDATE ON public.ride_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_ride_request_notification();


-- 3. Trigger Function for New Chat Messages
CREATE OR REPLACE FUNCTION public.handle_chat_message_notification()
RETURNS TRIGGER AS $$
DECLARE
    req_passenger UUID;
    req_driver UUID;
    recipient_id UUID;
    sender_name TEXT;
BEGIN
    -- Fetch passenger and driver IDs from ride_requests
    SELECT passenger_id, driver_id INTO req_passenger, req_driver
    FROM public.ride_requests
    WHERE id = NEW.request_id;

    IF NEW.sender_id = req_passenger THEN
        recipient_id := req_driver;
    ELSE
        recipient_id := req_passenger;
    END IF;

    -- Fetch sender name
    SELECT name INTO sender_name FROM public.users WHERE id = NEW.sender_id;
    IF sender_name IS NULL THEN
        sender_name := 'مستخدم';
    END IF;

    IF recipient_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            user_id,
            title,
            body,
            type,
            is_read,
            data,
            created_at
        ) VALUES (
            recipient_id,
            'رسالة جديدة من ' || sender_name || ' 💬',
            NEW.text,
            'chat_message',
            false,
            jsonb_build_object(
                'id', NEW.id,
                'tripId', NEW.request_id,
                'partnerId', NEW.sender_id,
                'partnerName', sender_name
            ),
            NOW()
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop and re-create trigger on chat_messages
DROP TRIGGER IF EXISTS trg_chat_message_notification ON public.chat_messages;
CREATE TRIGGER trg_chat_message_notification
    AFTER INSERT ON public.chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_chat_message_notification();
