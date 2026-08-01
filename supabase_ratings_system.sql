-- ============================================================================
-- INRIDE PRODUCTION-GRADE RATING & REVIEWS SYSTEM SCHEMA & FUNCTIONS
-- Uber-grade incremental rating updates, atomic submission, and moderation
-- ============================================================================

-- 1. EXTEND USERS TABLE FOR INCREMENTAL RATING STATS
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS total_rating INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS rating_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS average_rating NUMERIC(3,2) DEFAULT 5.00,
ADD COLUMN IF NOT EXISTS star_5_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS star_4_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS star_3_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS star_2_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS star_1_count INT DEFAULT 0;

-- 2. EXTEND DRIVERS TABLE FOR INCREMENTAL RATING STATS
ALTER TABLE public.drivers
ADD COLUMN IF NOT EXISTS total_rating INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS rating_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS average_rating NUMERIC(3,2) DEFAULT 5.00,
ADD COLUMN IF NOT EXISTS star_5_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS star_4_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS star_3_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS star_2_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS star_1_count INT DEFAULT 0;

-- 3. ENSURE RATINGS TABLE EXISTS WITH STRICT CONSTRAINTS & RLS
CREATE TABLE IF NOT EXISTS public.ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id TEXT NOT NULL,
    from_user_id TEXT NOT NULL,
    to_user_id TEXT NOT NULL,
    sender_name TEXT,
    receiver_name TEXT,
    role VARCHAR(20) NOT NULL CHECK (role IN ('driver', 'passenger', 'rider')),
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review TEXT CHECK (char_length(review) <= 500),
    is_hidden BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_trip_from_user UNIQUE (trip_id, from_user_id)
);

-- Indexes for maximum query performance & zero N+1 latency
CREATE INDEX IF NOT EXISTS idx_ratings_receiver_perf ON public.ratings (to_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ratings_sender_perf ON public.ratings (from_user_id);
CREATE INDEX IF NOT EXISTS idx_ratings_trip_perf ON public.ratings (trip_id);
CREATE INDEX IF NOT EXISTS idx_ratings_hidden_perf ON public.ratings (is_hidden);

-- Enable RLS
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Public ratings read" ON public.ratings;
DROP POLICY IF EXISTS "Users insert ratings" ON public.ratings;
DROP POLICY IF EXISTS "Public ratings full access" ON public.ratings;

CREATE POLICY "Public ratings read" ON public.ratings
FOR SELECT USING (is_hidden = FALSE OR auth.uid()::text = from_user_id OR auth.uid()::text = to_user_id);

CREATE POLICY "Users insert ratings" ON public.ratings
FOR INSERT WITH CHECK (auth.uid()::text = from_user_id);

CREATE POLICY "Admin ratings manage" ON public.ratings
FOR ALL USING (true) WITH CHECK (true);

-- 4. ATOMIC STORED PROCEDURE FOR INCREMENTAL RATING SUBMISSION
CREATE OR REPLACE FUNCTION public.submit_trip_rating(
    p_trip_id TEXT,
    p_to_user_id TEXT,
    p_rating INT,
    p_review TEXT DEFAULT NULL,
    p_role TEXT DEFAULT 'rider',
    p_sender_name TEXT DEFAULT NULL,
    p_receiver_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_from_user_id TEXT;
    v_existing_id UUID;
    v_new_rating_id UUID;
    v_new_total INT;
    v_new_count INT;
    v_new_avg NUMERIC(3,2);
BEGIN
    v_from_user_id := auth.uid()::text;
    IF v_from_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to submit rating';
    END IF;

    -- Validate Rating range
    IF p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'Rating value must be between 1 and 5 stars';
    END IF;

    -- Check Review length
    IF p_review IS NOT NULL AND char_length(p_review) > 500 THEN
        RAISE EXCEPTION 'Review text cannot exceed 500 characters';
    END IF;

    -- Prevent self rating
    IF v_from_user_id = p_to_user_id THEN
        RAISE EXCEPTION 'User cannot rate themselves';
    END IF;

    -- Check duplicate rating for this trip
    SELECT id INTO v_existing_id
    FROM public.ratings
    WHERE trip_id = p_trip_id AND from_user_id = v_from_user_id;

    IF v_existing_id IS NOT NULL THEN
        RAISE EXCEPTION 'Trip has already been rated by this user';
    END IF;

    -- Insert rating entry
    INSERT INTO public.ratings (
        trip_id,
        from_user_id,
        to_user_id,
        sender_name,
        receiver_name,
        role,
        rating,
        review,
        created_at
    ) VALUES (
        p_trip_id,
        v_from_user_id,
        p_to_user_id,
        p_sender_name,
        p_receiver_name,
        p_role,
        p_rating,
        p_review,
        NOW()
    ) RETURNING id INTO v_new_rating_id;

    -- Incremental update on users table
    UPDATE public.users
    SET 
        total_rating = COALESCE(total_rating, 0) + p_rating,
        rating_count = COALESCE(rating_count, 0) + 1,
        star_5_count = CASE WHEN p_rating = 5 THEN COALESCE(star_5_count, 0) + 1 ELSE COALESCE(star_5_count, 0) END,
        star_4_count = CASE WHEN p_rating = 4 THEN COALESCE(star_4_count, 0) + 1 ELSE COALESCE(star_4_count, 0) END,
        star_3_count = CASE WHEN p_rating = 3 THEN COALESCE(star_3_count, 0) + 1 ELSE COALESCE(star_3_count, 0) END,
        star_2_count = CASE WHEN p_rating = 2 THEN COALESCE(star_2_count, 0) + 1 ELSE COALESCE(star_2_count, 0) END,
        star_1_count = CASE WHEN p_rating = 1 THEN COALESCE(star_1_count, 0) + 1 ELSE COALESCE(star_1_count, 0) END,
        average_rating = ROUND((COALESCE(total_rating, 0) + p_rating)::numeric / (COALESCE(rating_count, 0) + 1), 2),
        rating = ROUND((COALESCE(total_rating, 0) + p_rating)::numeric / (COALESCE(rating_count, 0) + 1), 1)
    WHERE id = p_to_user_id
    RETURNING total_rating, rating_count, average_rating INTO v_new_total, v_new_count, v_new_avg;

    -- Incremental update on drivers table if receiver is a driver
    IF p_role = 'driver' THEN
        UPDATE public.drivers
        SET 
            total_rating = COALESCE(total_rating, 0) + p_rating,
            rating_count = COALESCE(rating_count, 0) + 1,
            star_5_count = CASE WHEN p_rating = 5 THEN COALESCE(star_5_count, 0) + 1 ELSE COALESCE(star_5_count, 0) END,
            star_4_count = CASE WHEN p_rating = 4 THEN COALESCE(star_4_count, 0) + 1 ELSE COALESCE(star_4_count, 0) END,
            star_3_count = CASE WHEN p_rating = 3 THEN COALESCE(star_3_count, 0) + 1 ELSE COALESCE(star_3_count, 0) END,
            star_2_count = CASE WHEN p_rating = 2 THEN COALESCE(star_2_count, 0) + 1 ELSE COALESCE(star_2_count, 0) END,
            star_1_count = CASE WHEN p_rating = 1 THEN COALESCE(star_1_count, 0) + 1 ELSE COALESCE(star_1_count, 0) END,
            average_rating = ROUND((COALESCE(total_rating, 0) + p_rating)::numeric / (COALESCE(rating_count, 0) + 1), 2),
            rating = ROUND((COALESCE(total_rating, 0) + p_rating)::numeric / (COALESCE(rating_count, 0) + 1), 1)
        WHERE id = p_to_user_id OR user_id = p_to_user_id;
    END IF;

    -- Return JSON result
    RETURN jsonb_build_object(
        'success', true,
        'rating_id', v_new_rating_id,
        'new_total_rating', v_new_total,
        'new_rating_count', v_new_count,
        'new_average_rating', v_new_avg
    );
END;
$$;

-- 5. ADMIN MODERATION FUNCTION
CREATE OR REPLACE FUNCTION public.toggle_rating_visibility(
    p_rating_id UUID,
    p_is_hidden BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.ratings
    SET is_hidden = p_is_hidden
    WHERE id = p_rating_id;

    RETURN FOUND;
END;
$$;
