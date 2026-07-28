-- ====================================================================
-- FIX: إصلاح إشعارات Push لأحداث الرحلة عبر Supabase pg_net
-- Project: inRide App 2026
-- 
-- هذا السكريبت يضيف إرسال Push Notifications مباشرة من Supabase
-- بدون الاعتماد على Flutter client، مما يضمن وصول الإشعارات دائماً.
-- ====================================================================

-- ────────────────────────────────────────────────────────────────────
-- 0. تفعيل pg_net extension (مطلوب لإرسال HTTP requests من PostgreSQL)
-- ────────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ────────────────────────────────────────────────────────────────────
-- 1. حفظ OneSignal credentials كـ Supabase Vault secrets
--    (يجب تنفيذ هذا يدوياً مرة واحدة مع القيم الحقيقية)
-- ────────────────────────────────────────────────────────────────────
-- NOTES: استبدل القيم التالية بالقيم الحقيقية من OneSignal Dashboard
-- INSERT INTO vault.secrets (name, secret) VALUES 
--   ('onesignal_app_id', '388d1944-0b83-4942-8f80-b12584def7d7'),
--   ('onesignal_rest_api_key', 'YOUR_REAL_REST_API_KEY_HERE')
-- ON CONFLICT (name) DO UPDATE SET secret = EXCLUDED.secret;

-- ────────────────────────────────────────────────────────────────────
-- 2. Helper Function: إرسال Push عبر OneSignal REST API من PostgreSQL
-- ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.send_onesignal_push(
    p_recipient_id UUID,
    p_title TEXT,
    p_body TEXT,
    p_type TEXT,
    p_data JSONB DEFAULT '{}'::JSONB,
    p_buttons JSONB DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_app_id TEXT;
    v_rest_key TEXT;
    v_payload JSONB;
    v_tokens TEXT[];
BEGIN
    SELECT decrypted_secret INTO v_app_id
    FROM vault.decrypted_secrets WHERE name = 'onesignal_app_id' LIMIT 1;

    SELECT decrypted_secret INTO v_rest_key
    FROM vault.decrypted_secrets WHERE name = 'onesignal_rest_api_key' LIMIT 1;

    IF v_app_id IS NULL OR v_app_id = '' OR v_rest_key IS NULL OR v_rest_key = '' THEN
        RETURN;
    END IF;

    -- Collect active subscription IDs for recipient from user_devices, users, and drivers tables
    SELECT array_agg(DISTINCT device_token) INTO v_tokens
    FROM (
        SELECT device_token FROM public.user_devices WHERE user_id = p_recipient_id AND is_active = true AND length(device_token) > 10
        UNION
        SELECT fcm_token AS device_token FROM public.users WHERE id = p_recipient_id AND fcm_token IS NOT NULL AND length(fcm_token) > 10
        UNION
        SELECT fcm_token AS device_token FROM public.drivers WHERE id = p_recipient_id AND fcm_token IS NOT NULL AND length(fcm_token) > 10
    ) sub;

    v_payload := jsonb_build_object(
        'app_id', v_app_id,
        'target_channel', 'push',
        'headings', jsonb_build_object('en', p_title, 'ar', p_title),
        'contents', jsonb_build_object('en', p_body, 'ar', p_body),
        'data', p_data || jsonb_build_object('type', p_type, 'recipientId', p_recipient_id::TEXT),
        'android_accent_color', 'FF1976D2',
        'priority', 10,
        'ttl', 86400
    );

    IF v_tokens IS NOT NULL AND array_length(v_tokens, 1) > 0 THEN
        v_payload := v_payload || jsonb_build_object('include_subscription_ids', to_jsonb(v_tokens));
    ELSE
        v_payload := v_payload || jsonb_build_object('include_aliases', jsonb_build_object('external_id', jsonb_build_array(p_recipient_id::TEXT)));
    END IF;

    IF p_buttons IS NOT NULL THEN
        v_payload := v_payload || jsonb_build_object('buttons', p_buttons);
    END IF;

    PERFORM net.http_post(
        url := 'https://api.onesignal.com/notifications',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Key ' || v_rest_key
        ),
        body := v_payload
    );

EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[OneSignal] Failed to dispatch push for user %: %', p_recipient_id, SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ────────────────────────────────────────────────────────────────────
-- 3. تحديث Trigger الإشعارات: حفظ في notifications + إرسال Push
-- ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_ride_request_push_notification()
RETURNS TRIGGER AS $$
DECLARE
    notif_title TEXT;
    notif_body TEXT;
    notif_type TEXT;
    recipient_id UUID;
    notif_data JSONB;
    drv RECORD;
    suitable_req RECORD;
BEGIN
    IF (TG_OP = 'INSERT') THEN
        IF NEW.status = 'Pending' THEN
            -- 1. إشعار للراكب تأكيد إنشاء الطلب
            recipient_id := NEW.passenger_id;
            notif_title  := 'تم تقديم طلب الرحلة 🚗';
            notif_body   := 'جاري البحث عن كابتن قريب...';
            notif_type   := 'new_ride_created';
            notif_data   := jsonb_build_object('requestId', NEW.id, 'tripId', NEW.id, 'status', NEW.status);

            INSERT INTO public.notifications (user_id, title, body, type, is_read, data, created_at)
            VALUES (recipient_id, notif_title, notif_body, notif_type, false, notif_data, NOW())
            ON CONFLICT DO NOTHING;

            PERFORM public.send_onesignal_push(
                p_recipient_id := recipient_id,
                p_title        := notif_title,
                p_body         := notif_body,
                p_type         := notif_type,
                p_data         := notif_data
            );

            -- 2. إشعار للسائقين المتصلين (is_online = true) بأنسب رحلة واحدة فقط
            FOR drv IN 
                SELECT id, current_latitude, current_longitude 
                FROM public.drivers 
                WHERE is_online = true AND COALESCE(is_available, true) = true
            LOOP
                -- اختيار أقرب وأنسب رحلة معلقة للسائق
                SELECT r.id, r.pickup_address, r.destination_address, r.offered_fare
                INTO suitable_req
                FROM public.ride_requests r
                WHERE r.status = 'Pending'
                ORDER BY (
                    CASE WHEN drv.current_latitude IS NOT NULL AND drv.current_longitude IS NOT NULL 
                              AND r.pickup_latitude IS NOT NULL AND r.pickup_longitude IS NOT NULL
                         THEN ((drv.current_latitude - r.pickup_latitude)^2 + (drv.current_longitude - r.pickup_longitude)^2)
                         ELSE 0 END
                ) ASC, r.created_at DESC
                LIMIT 1;

                IF suitable_req.id IS NOT NULL THEN
                    notif_title := 'رحلة جديدة متاحة 🚖 (' || COALESCE(suitable_req.offered_fare::TEXT, '0') || ' ج.م)';
                    notif_body  := 'من: ' || COALESCE(suitable_req.pickup_address, 'نقطة الاستلام') || ' إلى: ' || COALESCE(suitable_req.destination_address, 'الوجهة');
                    notif_data  := jsonb_build_object(
                        'requestId', suitable_req.id,
                        'tripId', suitable_req.id,
                        'status', 'Pending',
                        'fare', suitable_req.offered_fare
                    );

                    INSERT INTO public.notifications (user_id, title, body, type, is_read, data, created_at)
                    VALUES (drv.id, notif_title, notif_body, 'new_trip', false, notif_data, NOW())
                    ON CONFLICT DO NOTHING;

                    PERFORM public.send_onesignal_push(
                        p_recipient_id := drv.id,
                        p_title        := notif_title,
                        p_body         := notif_body,
                        p_type         := 'new_trip',
                        p_data         := notif_data,
                        p_buttons      := jsonb_build_array(
                            jsonb_build_object('id', 'accept_trip', 'text', 'قبول الرحلة ✅'),
                            jsonb_build_object('id', 'reject_trip', 'text', 'تجاهل ❌')
                        )
                    );
                END IF;
            END LOOP;

            RETURN NEW;
        END IF;

    ELSIF (TG_OP = 'UPDATE') THEN
        IF NEW.status = OLD.status THEN
            RETURN NEW;
        END IF;

        CASE NEW.status
            WHEN 'Accepted' THEN
                recipient_id := NEW.passenger_id;
                notif_title  := 'تم قبول طلب الرحلة 🎉';
                notif_body   := 'وافق الكابتن على رحلتك وهو في الطريق إليك الآن.';
                notif_type   := 'ride_accepted';
                notif_data   := jsonb_build_object('requestId', NEW.id, 'tripId', NEW.id, 'driverId', NEW.driver_id);

            WHEN 'DriverArriving', 'Arrived' THEN
                recipient_id := NEW.passenger_id;
                notif_title  := 'الكابتن وصل 📍';
                notif_body   := 'كابتن الرحلة وصل إلى نقطة الاستلام وهو بانتظارك.';
                notif_type   := 'captain_arrived';
                notif_data   := jsonb_build_object('requestId', NEW.id, 'tripId', NEW.id, 'driverId', NEW.driver_id);

            WHEN 'TripStarted' THEN
                recipient_id := NEW.passenger_id;
                notif_title  := 'بدأت الرحلة 🚀';
                notif_body   := 'رحلتك بدأت الآن. نتمنى لك رحلة سعيدة وآمنة.';
                notif_type   := 'trip_started';
                notif_data   := jsonb_build_object('requestId', NEW.id, 'tripId', NEW.id);

            WHEN 'Completed' THEN
                recipient_id := NEW.passenger_id;
                notif_title  := 'اكتملت الرحلة 🏁';
                notif_body   := 'تم إنهاء الرحلة بنجاح. شكراً لاستخدامك inRide.';
                notif_type   := 'trip_finished';
                notif_data   := jsonb_build_object('requestId', NEW.id, 'tripId', NEW.id, 'price', COALESCE(NEW.offered_fare, 0));

            WHEN 'Cancelled' THEN
                IF NEW.cancelled_by = 'driver' THEN
                    recipient_id := NEW.passenger_id;
                    notif_body   := 'قام الكابتن بإلغاء الرحلة.';
                ELSE
                    recipient_id := NEW.driver_id;
                    notif_body   := 'قام الراكب بإلغاء الرحلة.';
                END IF;
                notif_title := 'تم إلغاء الرحلة ❌';
                notif_type  := 'cancel_trip';
                notif_data  := jsonb_build_object('requestId', NEW.id, 'tripId', NEW.id, 'cancelledBy', COALESCE(NEW.cancelled_by, 'unknown'));

            WHEN 'Expired' THEN
                recipient_id := NEW.passenger_id;
                notif_title  := 'انتهت فترة البحث ⏱️';
                notif_body   := 'لم يتم العثور على كابتن متاح. يمكنك إعادة المحاولة.';
                notif_type   := 'ride_expired';
                notif_data   := jsonb_build_object('requestId', NEW.id, 'tripId', NEW.id);

            ELSE
                RETURN NEW;
        END CASE;
    END IF;

    IF recipient_id IS NOT NULL THEN
        -- حفظ في notifications table
        INSERT INTO public.notifications (user_id, title, body, type, is_read, data, created_at)
        VALUES (recipient_id, notif_title, notif_body, notif_type, false, notif_data, NOW())
        ON CONFLICT DO NOTHING;

        -- إرسال Push Notification عبر OneSignal
        PERFORM public.send_onesignal_push(
            p_recipient_id := recipient_id,
            p_title        := notif_title,
            p_body         := notif_body,
            p_type         := notif_type,
            p_data         := notif_data
        );
    END IF;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[RideTrigger] Error: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_ride_request_push_notification ON public.ride_requests;
CREATE TRIGGER trg_ride_request_push_notification
    AFTER INSERT OR UPDATE ON public.ride_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_ride_request_push_notification();

-- ────────────────────────────────────────────────────────────────────
-- 4. تحديث Trigger عروض الكابتن (ride_offers)
-- ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_ride_offer_push_notification()
RETURNS TRIGGER AS $$
DECLARE
    notif_data JSONB;
BEGIN
    IF (TG_OP = 'INSERT') THEN
        notif_data := jsonb_build_object(
            'offerId', NEW.id,
            'requestId', NEW.request_id,
            'tripId', NEW.request_id,
            'driverId', NEW.driver_id,
            'price', NEW.price
        );

        INSERT INTO public.notifications (user_id, title, body, type, is_read, data, created_at)
        VALUES (
            NEW.passenger_id,
            'عرض جديد من كابتن 🏷️',
            'قدّم الكابتن ' || COALESCE(NEW.driver_name, 'سائق') || ' عرضاً بقيمة ' || COALESCE(NEW.price::TEXT, '0') || ' ج.م',
            'new_offer',
            false,
            notif_data,
            NOW()
        );

        PERFORM public.send_onesignal_push(
            p_recipient_id := NEW.passenger_id,
            p_title        := 'عرض جديد من كابتن 🏷️',
            p_body         := 'قدّم الكابتن ' || COALESCE(NEW.driver_name, 'سائق') || ' عرضاً بقيمة ' || COALESCE(NEW.price::TEXT, '0') || ' ج.م',
            p_type         := 'new_offer',
            p_data         := notif_data
        );
    END IF;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[OfferTrigger] Error: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_ride_offer_push_notification ON public.ride_offers;
CREATE TRIGGER trg_ride_offer_push_notification
    AFTER INSERT ON public.ride_offers
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_ride_offer_push_notification();

-- ────────────────────────────────────────────────────────────────────
-- 5. تحديث Trigger رسائل المحادثة (chat_messages) — إرسال Push للطرف الآخر
-- ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_chat_message_push_notification()
RETURNS TRIGGER AS $$
DECLARE
    req_passenger UUID;
    req_driver UUID;
    recipient_id UUID;
    sender_name TEXT;
    notif_data JSONB;
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
        notif_data := jsonb_build_object(
            'id', NEW.id,
            'tripId', NEW.request_id,
            'ride_id', NEW.request_id,
            'partnerId', NEW.sender_id,
            'sender_id', NEW.sender_id,
            'receiver_id', recipient_id,
            'partnerName', sender_name,
            'action', 'open_chat'
        );

        INSERT INTO public.notifications (user_id, title, body, type, is_read, data, created_at)
        VALUES (
            recipient_id,
            'رسالة جديدة من ' || sender_name || ' 💬',
            NEW.text,
            'chat_message',
            false,
            notif_data,
            NOW()
        );

        PERFORM public.send_onesignal_push(
            p_recipient_id := recipient_id,
            p_title        := 'رسالة جديدة من ' || sender_name || ' 💬',
            p_body         := NEW.text,
            p_type         := 'chat_message',
            p_data         := notif_data
        );
    END IF;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[ChatTrigger] Error: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_chat_message_push_notification ON public.chat_messages;
CREATE TRIGGER trg_chat_message_push_notification
    AFTER INSERT ON public.chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_chat_message_push_notification();

-- ────────────────────────────────────────────────────────────────────
-- 6. أوامر التحقق بعد التنفيذ
-- ────────────────────────────────────────────────────────────────────
-- SELECT name FROM vault.decrypted_secrets WHERE name IN ('onesignal_app_id', 'onesignal_rest_api_key');
-- SELECT trigger_name, event_manipulation, event_object_table
-- FROM information_schema.triggers
-- WHERE trigger_name IN ('trg_ride_request_push_notification', 'trg_ride_offer_push_notification', 'trg_chat_message_push_notification');
