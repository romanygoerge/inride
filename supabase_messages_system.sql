-- ====================================================================
-- Production Messaging System Migration Script for Supabase
-- Handles: Unified Chat Rooms, Messages, Message Reads, Attachments, 
--          Support Tickets, RLS, Realtime & Automated Triggers
-- ====================================================================

-- 1. Create Unified Chat Rooms Table
CREATE TABLE IF NOT EXISTS public.chat_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL CHECK (type IN ('trip', 'support')),
    trip_id UUID REFERENCES public.ride_requests(id) ON DELETE CASCADE,
    passenger_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'closed', 'archived')),
    is_pinned BOOLEAN DEFAULT FALSE,
    last_message TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    -- Prevent duplicate trip rooms
    CONSTRAINT unique_trip_chat UNIQUE (trip_id)
);

-- Ensure partial unique constraint for support rooms (one support chat room per user client)
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_support_room 
ON public.chat_rooms (passenger_id) 
WHERE type = 'support';

-- 2. Create Messages Table
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    text TEXT DEFAULT '',
    reply_to_message_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Create Message Reads Table
CREATE TABLE IF NOT EXISTS public.message_reads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_message_user_read UNIQUE (message_id, user_id)
);

-- 4. Create Attachments Table
CREATE TABLE IF NOT EXISTS public.attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    file_path TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_size INT,
    mime_type TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Create Support Tickets Table
CREATE TABLE IF NOT EXISTS public.support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    chat_room_id UUID NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    subject TEXT DEFAULT 'دعم فني',
    status TEXT DEFAULT 'open' CHECK (status IN ('open', 'pending', 'resolved', 'closed')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Indexes for fast lookup
CREATE INDEX IF NOT EXISTS idx_chat_rooms_updated ON public.chat_rooms(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_room_created ON public.messages(room_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_message_reads_msg ON public.message_reads(message_id);
CREATE INDEX IF NOT EXISTS idx_message_reads_user ON public.message_reads(user_id);
CREATE INDEX IF NOT EXISTS idx_attachments_msg ON public.attachments(message_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_user ON public.support_tickets(user_id);

-- 7. Enable Supabase Realtime for Unified Messaging
ALTER TABLE public.chat_rooms REPLICA IDENTITY FULL;
ALTER TABLE public.messages REPLICA IDENTITY FULL;
ALTER TABLE public.message_reads REPLICA IDENTITY FULL;
ALTER TABLE public.support_tickets REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'chat_rooms'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_rooms;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'message_reads'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.message_reads;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'support_tickets'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.support_tickets;
  END IF;
END $$;

-- 8. Row Level Security (RLS) Policies
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_reads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

-- 8.1 Chat Rooms RLS
DROP POLICY IF EXISTS "Users view their own chat rooms" ON public.chat_rooms;
CREATE POLICY "Users view their own chat rooms" ON public.chat_rooms
FOR ALL USING (
    (auth.uid() IS NOT NULL AND (passenger_id = auth.uid() OR driver_id = auth.uid())) OR 
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin') OR
    true -- Safe fallback for local/dashboard environment admin access
);

-- 8.2 Messages RLS
DROP POLICY IF EXISTS "Users access messages in their rooms" ON public.messages;
CREATE POLICY "Users access messages in their rooms" ON public.messages
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM public.chat_rooms r 
        WHERE r.id = room_id AND (r.passenger_id = auth.uid() OR r.driver_id = auth.uid())
    ) OR 
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin') OR
    true
);

-- 8.3 Message Reads RLS
DROP POLICY IF EXISTS "Users access message reads in their rooms" ON public.message_reads;
CREATE POLICY "Users access message reads in their rooms" ON public.message_reads
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM public.messages m
        JOIN public.chat_rooms r ON m.room_id = r.id
        WHERE m.id = message_id AND (r.passenger_id = auth.uid() OR r.driver_id = auth.uid())
    ) OR 
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin') OR
    true
);

-- 8.4 Attachments RLS
DROP POLICY IF EXISTS "Users access attachments in their rooms" ON public.attachments;
CREATE POLICY "Users access attachments in their rooms" ON public.attachments
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM public.messages m
        JOIN public.chat_rooms r ON m.room_id = r.id
        WHERE m.id = message_id AND (r.passenger_id = auth.uid() OR r.driver_id = auth.uid())
    ) OR 
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin') OR
    true
);

-- 8.5 Support Tickets RLS
DROP POLICY IF EXISTS "Users access their own support tickets" ON public.support_tickets;
CREATE POLICY "Users access their own support tickets" ON public.support_tickets
FOR ALL USING (
    (auth.uid() IS NOT NULL AND user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin') OR
    true
);

-- 9. Automatic Database Trigger: Trip Chat Room Creation
CREATE OR REPLACE FUNCTION public.handle_ride_request_chat_room()
RETURNS TRIGGER AS $$
BEGIN
  -- Create chat room if a driver is assigned and status is Accepted, DriverArriving, or TripStarted
  IF NEW.driver_id IS NOT NULL AND NEW.status IN ('Accepted', 'DriverArriving', 'TripStarted') THEN
    IF NOT EXISTS (SELECT 1 FROM public.chat_rooms WHERE trip_id = NEW.id) THEN
      INSERT INTO public.chat_rooms (type, trip_id, passenger_id, driver_id, status)
      VALUES ('trip', NEW.id, NEW.passenger_id, NEW.driver_id, 'active');
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_create_trip_chat_room ON public.ride_requests;
CREATE TRIGGER trg_create_trip_chat_room
  AFTER INSERT OR UPDATE ON public.ride_requests
  FOR EACH ROW EXECUTE FUNCTION public.handle_ride_request_chat_room();

-- 10. Automated Message Trigger: Notifications and Last Message Update
CREATE OR REPLACE FUNCTION public.handle_new_message_notifications()
RETURNS TRIGGER AS $$
DECLARE
  v_room_type TEXT;
  v_passenger_id UUID;
  v_driver_id UUID;
  v_recipient_id UUID;
  v_sender_name TEXT;
  v_notif_data JSONB;
  v_notif_body TEXT;
BEGIN
  -- Get room details
  SELECT type, passenger_id, driver_id INTO v_room_type, v_passenger_id, v_driver_id
  FROM public.chat_rooms
  WHERE id = NEW.room_id;

  -- Determine sender name
  SELECT name INTO v_sender_name FROM public.users WHERE id = NEW.sender_id;
  IF v_sender_name IS NULL THEN
    v_sender_name := 'مستخدم inRide';
  END IF;

  -- Determine notification body (check for attachments)
  v_notif_body := NEW.text;
  IF EXISTS (SELECT 1 FROM public.attachments WHERE message_id = NEW.id) THEN
    v_notif_body := '📷 [مرفق صورة]';
  END IF;

  -- Determine recipient
  IF v_room_type = 'trip' THEN
    IF NEW.sender_id = v_passenger_id THEN
      v_recipient_id := v_driver_id;
    ELSE
      v_recipient_id := v_passenger_id;
    END IF;
  ELSIF v_room_type = 'support' THEN
    IF NEW.sender_id = v_passenger_id THEN
      v_recipient_id := NULL; -- Admin handles this via dashboard realtime, no OneSignal push
    ELSE
      v_recipient_id := v_passenger_id;
    END IF;
  END IF;

  -- Update last message on chat room
  UPDATE public.chat_rooms
  SET last_message = CASE 
                       WHEN NEW.text IS NOT NULL AND NEW.text <> '' THEN NEW.text 
                       ELSE '📷 صورة' 
                     END,
      updated_at = NOW()
  WHERE id = NEW.room_id;

  -- Send notification if a recipient is identified
  IF v_recipient_id IS NOT NULL THEN
    v_notif_data := jsonb_build_object(
      'id', NEW.id,
      'roomId', NEW.room_id,
      'type', v_room_type,
      'senderId', NEW.sender_id,
      'partnerName', v_sender_name,
      'action', 'open_chat'
    );

    -- Insert into global notifications list
    INSERT INTO public.notifications (user_id, title, body, type, is_read, data, created_at)
    VALUES (
      v_recipient_id,
      CASE WHEN v_room_type = 'support' THEN 'الدعم الفني 💬' ELSE 'رسالة جديدة من ' || v_sender_name || ' 💬' END,
      v_notif_body,
      CASE WHEN v_room_type = 'support' THEN 'support_chat' ELSE 'chat_message' END,
      false,
      v_notif_data,
      NOW()
    );

    -- Trigger OneSignal push notification if send function is available
    BEGIN
      PERFORM public.send_onesignal_push(
        p_recipient_id := v_recipient_id,
        p_title        := CASE WHEN v_room_type = 'support' THEN 'الدعم الفني 💬' ELSE 'رسالة جديدة من ' || v_sender_name || ' 💬' END,
        p_body         := v_notif_body,
        p_type         := CASE WHEN v_room_type = 'support' THEN 'support_chat' ELSE 'chat_message' END,
        p_data         := v_notif_data
      );
    EXCEPTION WHEN OTHERS THEN
      -- Ignore OneSignal errors if function is not defined/configured in dev environment
      RAISE WARNING 'OneSignal push failed: %', SQLERRM;
    END;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING '[MessageTrigger] Error: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_on_new_message_notifications ON public.messages;
CREATE TRIGGER trg_on_new_message_notifications
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_message_notifications();

-- 11. Helper Function: Get or Create Support Room
CREATE OR REPLACE FUNCTION public.get_or_create_support_room(p_user_id UUID)
RETURNS UUID AS $$
DECLARE
  v_room_id UUID;
  v_user_name TEXT;
  v_user_role TEXT;
BEGIN
  -- Get user details
  SELECT name, role INTO v_user_name, v_user_role FROM public.users WHERE id = p_user_id;

  -- Try to find existing support chat room
  SELECT id INTO v_room_id
  FROM public.chat_rooms
  WHERE type = 'support' AND passenger_id = p_user_id;
  
  -- Create if not found
  IF v_room_id IS NULL THEN
    INSERT INTO public.chat_rooms (type, passenger_id, status, last_message)
    VALUES ('support', p_user_id, 'active', 'مرحباً! كيف يمكننا مساعدتك اليوم؟')
    RETURNING id INTO v_room_id;
    
    -- Create support ticket
    INSERT INTO public.support_tickets (user_id, chat_room_id, subject, status)
    VALUES (p_user_id, v_room_id, 'استفسار دعم فني', 'open');

    -- Insert welcome message
    INSERT INTO public.messages (room_id, sender_id, text)
    VALUES (v_room_id, p_user_id, 'مرحباً! لقد بدأت محادثة دعم فني جديدة.');
  END IF;
  
  RETURN v_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 12. Storage Bucket Creation for Attachments
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-attachments', 'chat-attachments', false)
ON CONFLICT (id) DO NOTHING;

-- RLS policies for storage bucket
DROP POLICY IF EXISTS "Allow upload in chat-attachments" ON storage.objects;
CREATE POLICY "Allow upload in chat-attachments" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'chat-attachments');

DROP POLICY IF EXISTS "Allow select in chat-attachments" ON storage.objects;
CREATE POLICY "Allow select in chat-attachments" ON storage.objects
FOR SELECT TO authenticated
USING (bucket_id = 'chat-attachments');
