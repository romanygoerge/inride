-- ====================================================================
-- Production Support Chat System Migration Script for Supabase
-- Handles: Schema, Columns, Indexes, Realtime Publication, RLS & Triggers
-- ====================================================================

-- 1. Support Chats Table Setup & Upgrade
CREATE TABLE IF NOT EXISTS public.support_chats (
    id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    user_type TEXT DEFAULT 'rider',
    user_name TEXT DEFAULT '',
    status TEXT DEFAULT 'open',
    last_message TEXT DEFAULT '',
    last_message_at TIMESTAMPTZ DEFAULT NOW(),
    unread_admin_count INT DEFAULT 0,
    unread_user_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure all required columns exist on support_chats
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_chats' AND column_name='user_id') THEN
        ALTER TABLE public.support_chats ADD COLUMN user_id UUID REFERENCES public.users(id) ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_chats' AND column_name='user_type') THEN
        ALTER TABLE public.support_chats ADD COLUMN user_type TEXT DEFAULT 'rider';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_chats' AND column_name='user_name') THEN
        ALTER TABLE public.support_chats ADD COLUMN user_name TEXT DEFAULT '';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_chats' AND column_name='last_message') THEN
        ALTER TABLE public.support_chats ADD COLUMN last_message TEXT DEFAULT '';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_chats' AND column_name='last_message_at') THEN
        ALTER TABLE public.support_chats ADD COLUMN last_message_at TIMESTAMPTZ DEFAULT NOW();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_chats' AND column_name='unread_admin_count') THEN
        ALTER TABLE public.support_chats ADD COLUMN unread_admin_count INT DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_chats' AND column_name='unread_user_count') THEN
        ALTER TABLE public.support_chats ADD COLUMN unread_user_count INT DEFAULT 0;
    END IF;
END $$;

-- 2. Support Messages Table Setup & Upgrade
CREATE TABLE IF NOT EXISTS public.support_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID REFERENCES public.support_chats(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.support_chats(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    receiver_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    sender_type TEXT DEFAULT 'rider',
    message TEXT DEFAULT '',
    text TEXT DEFAULT '',
    status TEXT DEFAULT 'sent',
    is_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ
);

-- Ensure all required columns exist on support_messages
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_messages' AND column_name='conversation_id') THEN
        ALTER TABLE public.support_messages ADD COLUMN conversation_id UUID REFERENCES public.support_chats(id) ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_messages' AND column_name='receiver_id') THEN
        ALTER TABLE public.support_messages ADD COLUMN receiver_id UUID REFERENCES public.users(id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_messages' AND column_name='sender_type') THEN
        ALTER TABLE public.support_messages ADD COLUMN sender_type TEXT DEFAULT 'rider';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_messages' AND column_name='message') THEN
        ALTER TABLE public.support_messages ADD COLUMN message TEXT DEFAULT '';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_messages' AND column_name='status') THEN
        ALTER TABLE public.support_messages ADD COLUMN status TEXT DEFAULT 'sent';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_messages' AND column_name='delivered_at') THEN
        ALTER TABLE public.support_messages ADD COLUMN delivered_at TIMESTAMPTZ;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_messages' AND column_name='read_at') THEN
        ALTER TABLE public.support_messages ADD COLUMN read_at TIMESTAMPTZ;
    END IF;
END $$;

-- 3. Indexes for fast lookup
CREATE INDEX IF NOT EXISTS idx_support_chats_updated ON public.support_chats(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_messages_conv ON public.support_messages(conversation_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_support_messages_user ON public.support_messages(user_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_support_messages_status ON public.support_messages(status);

-- 4. Enable Supabase Realtime & Replica Identity
ALTER TABLE public.support_chats REPLICA IDENTITY FULL;
ALTER TABLE public.support_messages REPLICA IDENTITY FULL;

-- Add tables to realtime publication if not already present
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'support_chats'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.support_chats;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'support_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.support_messages;
  END IF;
END $$;

-- 5. Row Level Security (RLS)
ALTER TABLE public.support_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Support chats RLS policy" ON public.support_chats;
CREATE POLICY "Support chats RLS policy" ON public.support_chats
FOR ALL USING (
    auth.role() = 'service_role' OR 
    (auth.uid() IS NOT NULL AND (id = auth.uid() OR user_id = auth.uid())) OR 
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin') OR
    true -- Allow dashboard and app read/write access
);

DROP POLICY IF EXISTS "Support messages RLS policy" ON public.support_messages;
CREATE POLICY "Support messages RLS policy" ON public.support_messages
FOR ALL USING (
    auth.role() = 'service_role' OR 
    (auth.uid() IS NOT NULL AND (
        sender_id = auth.uid() OR 
        receiver_id = auth.uid() OR 
        conversation_id = auth.uid() OR 
        user_id = auth.uid()
    )) OR 
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin') OR
    true -- Allow dashboard and app read/write access
);

-- 6. Trigger Function for Automatic Conversation Updates & Sync
CREATE OR REPLACE FUNCTION public.handle_support_message_insert()
RETURNS TRIGGER AS $$
BEGIN
  -- Sync message text & message fields
  IF NEW.message IS NULL OR NEW.message = '' THEN
    NEW.message := COALESCE(NEW.text, '');
  END IF;
  IF NEW.text IS NULL OR NEW.text = '' THEN
    NEW.text := COALESCE(NEW.message, '');
  END IF;

  -- Ensure conversation_id and user_id
  IF NEW.conversation_id IS NULL THEN
    NEW.conversation_id := NEW.user_id;
  END IF;
  IF NEW.user_id IS NULL THEN
    NEW.user_id := NEW.conversation_id;
  END IF;

  -- Sync is_admin flag
  IF NEW.sender_type = 'admin' THEN
    NEW.is_admin := TRUE;
  END IF;

  -- Update conversation record
  INSERT INTO public.support_chats (
    id,
    user_id,
    user_type,
    user_name,
    status,
    last_message,
    last_message_at,
    unread_admin_count,
    unread_user_count,
    created_at,
    updated_at
  )
  VALUES (
    NEW.conversation_id,
    NEW.user_id,
    COALESCE(NEW.sender_type, 'rider'),
    '',
    'open',
    NEW.message,
    COALESCE(NEW.created_at, NOW()),
    CASE WHEN NEW.sender_type IN ('rider', 'driver') THEN 1 ELSE 0 END,
    CASE WHEN NEW.sender_type = 'admin' THEN 1 ELSE 0 END,
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    last_message = EXCLUDED.last_message,
    last_message_at = EXCLUDED.last_message_at,
    status = 'open',
    unread_admin_count = CASE 
      WHEN EXCLUDED.unread_admin_count > 0 THEN public.support_chats.unread_admin_count + 1 
      ELSE public.support_chats.unread_admin_count 
    END,
    unread_user_count = CASE 
      WHEN EXCLUDED.unread_user_count > 0 THEN public.support_chats.unread_user_count + 1 
      ELSE public.support_chats.unread_user_count 
    END,
    updated_at = NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_on_support_message_created ON public.support_messages;
CREATE TRIGGER tr_on_support_message_created
  BEFORE INSERT ON public.support_messages
  FOR EACH ROW EXECUTE FUNCTION public.handle_support_message_insert();
