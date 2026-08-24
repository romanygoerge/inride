-- ==========================================================
-- SUPABASE POSTGIS & SMART PLACE SEARCH SYSTEM (inRide App)
-- ==========================================================

-- 1. Enable Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "unaccent";

-- 2. Arabic Normalization Function
-- Cleans text, normalizes Alefs, Taa Marbuta, Yaa, and removes diacritics (Tashkeel)
CREATE OR REPLACE FUNCTION public.normalize_arabic(p_text TEXT)
RETURNS TEXT AS $$
DECLARE
    v_result TEXT;
BEGIN
    IF p_text IS NULL THEN
        RETURN '';
    END IF;
    v_result := lower(trim(p_text));
    -- Normalize Alef variants: أ, إ, آ, ٱ -> ا
    v_result := regexp_replace(v_result, '[إأآٱ]', 'ا', 'g');
    -- Normalize Taa Marbuta: ة -> ه
    v_result := regexp_replace(v_result, 'ة', 'ه', 'g');
    -- Normalize Yaa: ى -> ي
    v_result := regexp_replace(v_result, 'ى', 'ي', 'g');
    -- Remove Arabic diacritics (Fatha, Damma, Kasra, Tanween, Sukun, Shadda, etc.)
    v_result := regexp_replace(v_result, '[\u064B-\u065F\u0670]', '', 'g');
    -- Remove redundant spaces
    v_result := regexp_replace(v_result, '\s+', ' ', 'g');
    RETURN v_result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 3. Places Master Table
CREATE TABLE IF NOT EXISTS public.places (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name_ar TEXT NOT NULL,
    name_en TEXT NOT NULL DEFAULT '',
    name_normalized TEXT GENERATED ALWAYS AS (public.normalize_arabic(name_ar)) STORED,
    address_ar TEXT DEFAULT '',
    address_en TEXT DEFAULT '',
    category TEXT DEFAULT 'landmark' CHECK (category IN (
        'landmark', 'university', 'school', 'hospital', 'mall', 
        'store', 'station', 'airport', 'restaurant', 'cafe', 
        'government', 'residential', 'other'
    )),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    location GEOGRAPHY(Point, 4326) GENERATED ALWAYS AS (
        ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
    ) STORED,
    aliases TEXT[] DEFAULT '{}',
    popularity INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for Places
CREATE INDEX IF NOT EXISTS idx_places_location ON public.places USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_places_name_normalized_trgm ON public.places USING GIN (name_normalized gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_places_name_en_trgm ON public.places USING GIN (lower(name_en) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_places_category ON public.places (category);
CREATE INDEX IF NOT EXISTS idx_places_popularity ON public.places (popularity DESC);
CREATE INDEX IF NOT EXISTS idx_places_active ON public.places (is_active);

-- 4. User Saved Places Table (Home, Work, Favorites)
CREATE TABLE IF NOT EXISTS public.user_saved_places (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    place_id UUID REFERENCES public.places(id) ON DELETE SET NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    address TEXT NOT NULL DEFAULT '',
    icon TEXT DEFAULT 'star', -- 'home', 'work', 'star', 'school', etc.
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unq_user_saved_title UNIQUE (user_id, title)
);

CREATE INDEX IF NOT EXISTS idx_user_saved_places_user ON public.user_saved_places(user_id);

-- 5. User Search History Table (Recent & Frequent Locations)
CREATE TABLE IF NOT EXISTS public.user_search_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    place_id UUID REFERENCES public.places(id) ON DELETE SET NULL,
    query TEXT DEFAULT '',
    place_name TEXT NOT NULL,
    formatted_address TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    search_count INT DEFAULT 1,
    last_searched_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_search_history_user ON public.user_search_history(user_id, last_searched_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_search_history_coords ON public.user_search_history(user_id, latitude, longitude);

-- 6. RPC Function: Multi-Factor Smart Search with PostGIS
CREATE OR REPLACE FUNCTION public.search_places(
    p_query TEXT DEFAULT '',
    p_lat DOUBLE PRECISION DEFAULT 30.0444,
    p_lng DOUBLE PRECISION DEFAULT 31.2357,
    p_radius_km DOUBLE PRECISION DEFAULT 150.0,
    p_limit INT DEFAULT 20,
    p_user_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    name_ar TEXT,
    name_en TEXT,
    address_ar TEXT,
    address_en TEXT,
    category TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    distance_meters DOUBLE PRECISION,
    distance_km DOUBLE PRECISION,
    text_score DOUBLE PRECISION,
    distance_score DOUBLE PRECISION,
    popularity_score DOUBLE PRECISION,
    recency_boost DOUBLE PRECISION,
    is_saved BOOLEAN,
    is_history BOOLEAN,
    final_score DOUBLE PRECISION
) AS $$
DECLARE
    v_user_point GEOGRAPHY;
    v_query_raw TEXT;
    v_query_norm TEXT;
    v_query_en TEXT;
    v_query_words TEXT[];
    v_has_query BOOLEAN;
    v_max_dist DOUBLE PRECISION;
BEGIN
    v_user_point := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography;
    v_query_raw := trim(coalesce(p_query, ''));
    v_query_norm := public.normalize_arabic(v_query_raw);
    v_query_en := lower(v_query_raw);
    v_has_query := length(v_query_norm) > 0;
    v_max_dist := p_radius_km * 1000.0;
    
    IF v_has_query THEN
        v_query_words := string_to_array(v_query_norm, ' ');
    ELSE
        v_query_words := ARRAY[]::TEXT[];
    END IF;

    RETURN QUERY
    WITH place_metrics AS (
        SELECT
            p.id,
            p.name_ar,
            p.name_en,
            p.address_ar,
            p.address_en,
            p.category,
            p.latitude,
            p.longitude,
            p.popularity,
            ST_Distance(p.location, v_user_point)::DOUBLE PRECISION AS dist_meters,
            (
                p_user_id IS NOT NULL AND EXISTS(
                    SELECT 1 FROM public.user_search_history ush 
                    WHERE ush.user_id = p_user_id 
                      AND (ush.place_id = p.id OR (abs(ush.latitude - p.latitude) < 0.0005 AND abs(ush.longitude - p.longitude) < 0.0005))
                )
            ) AS was_recently_used,
            (
                p_user_id IS NOT NULL AND EXISTS(
                    SELECT 1 FROM public.user_saved_places usp
                    WHERE usp.user_id = p_user_id 
                      AND (usp.place_id = p.id OR (abs(usp.latitude - p.latitude) < 0.0005 AND abs(usp.longitude - p.longitude) < 0.0005))
                )
            ) AS was_saved,
            (
                CASE 
                    WHEN NOT v_has_query THEN 1.0::DOUBLE PRECISION
                    -- 1. Exact match with name or aliases
                    WHEN p.name_normalized = v_query_norm OR lower(p.name_en) = v_query_en THEN 1.0::DOUBLE PRECISION
                    WHEN EXISTS (
                        SELECT 1 FROM unnest(p.aliases) a 
                        WHERE public.normalize_arabic(a) = v_query_norm OR lower(a) = v_query_en
                    ) THEN 0.98::DOUBLE PRECISION
                    -- 2. Starts with query
                    WHEN p.name_normalized LIKE v_query_norm || '%' OR lower(p.name_en) LIKE v_query_en || '%' THEN 0.92::DOUBLE PRECISION
                    -- 3. All query words exist in name (e.g. "جامعة" and "السادات" in "جامعة مدينة السادات")
                    WHEN (
                        array_length(v_query_words, 1) > 1 AND (
                            SELECT bool_and(p.name_normalized LIKE '%' || w || '%' OR lower(p.name_en) LIKE '%' || w || '%')
                            FROM unnest(v_query_words) w WHERE length(w) > 1
                        )
                    ) THEN 0.90::DOUBLE PRECISION
                    -- 4. Substring / Alias substring match
                    WHEN EXISTS (
                        SELECT 1 FROM unnest(p.aliases) a 
                        WHERE public.normalize_arabic(a) LIKE '%' || v_query_norm || '%' OR lower(a) LIKE '%' || v_query_en || '%'
                    ) THEN 0.85::DOUBLE PRECISION
                    WHEN p.name_normalized LIKE '% ' || v_query_norm || '%' OR lower(p.name_en) LIKE '% ' || v_query_en || '%' THEN 0.80::DOUBLE PRECISION
                    WHEN p.name_normalized LIKE '%' || v_query_norm || '%' OR lower(p.name_en) LIKE '%' || v_query_en || '%' THEN 0.70::DOUBLE PRECISION
                    -- 5. Trigram and Word Similarity across Name, Aliases and Address
                    ELSE GREATEST(
                        similarity(p.name_normalized, v_query_norm)::DOUBLE PRECISION,
                        similarity(lower(p.name_en), v_query_en)::DOUBLE PRECISION,
                        word_similarity(v_query_norm, p.name_normalized)::DOUBLE PRECISION,
                        word_similarity(v_query_en, lower(p.name_en))::DOUBLE PRECISION,
                        (
                            SELECT COALESCE(MAX(GREATEST(
                                similarity(public.normalize_arabic(a), v_query_norm),
                                word_similarity(v_query_norm, public.normalize_arabic(a))
                            )), 0.0)::DOUBLE PRECISION
                            FROM unnest(p.aliases) a
                        ),
                        (similarity(public.normalize_arabic(coalesce(p.address_ar, '')), v_query_norm) * 0.65)::DOUBLE PRECISION,
                        (similarity(lower(coalesce(p.address_en, '')), v_query_en) * 0.65)::DOUBLE PRECISION
                    )
                END
            ) AS raw_text_score
        FROM public.places p
        WHERE p.is_active = TRUE
          AND (
              (NOT v_has_query AND ST_DWithin(p.location, v_user_point, v_max_dist))
              OR (
                  v_has_query AND (
                      ST_DWithin(p.location, v_user_point, v_max_dist)
                      OR p.name_normalized LIKE '%' || v_query_norm || '%'
                      OR lower(p.name_en) LIKE '%' || v_query_en || '%'
                      OR similarity(p.name_normalized, v_query_norm) > 0.18
                      OR similarity(lower(p.name_en), v_query_en) > 0.18
                      OR word_similarity(v_query_norm, p.name_normalized) > 0.30
                      OR EXISTS (
                          SELECT 1 FROM unnest(p.aliases) a 
                          WHERE public.normalize_arabic(a) LIKE '%' || v_query_norm || '%' 
                             OR lower(a) LIKE '%' || v_query_en || '%'
                             OR similarity(public.normalize_arabic(a), v_query_norm) > 0.25
                             OR word_similarity(v_query_norm, public.normalize_arabic(a)) > 0.35
                      )
                  )
              )
          )
    ),
    scored_places AS (
        SELECT
            pm.id,
            pm.name_ar,
            pm.name_en,
            pm.address_ar,
            pm.address_en,
            pm.category,
            pm.latitude,
            pm.longitude,
            pm.dist_meters,
            (pm.dist_meters / 1000.0)::DOUBLE PRECISION AS dist_km,
            pm.raw_text_score AS text_score,
            (1.0 / (1.0 + (pm.dist_meters / 5000.0)))::DOUBLE PRECISION AS dist_score,
            LEAST(pm.popularity::DOUBLE PRECISION / 100.0, 1.0::DOUBLE PRECISION) AS pop_score,
            (CASE WHEN pm.was_saved THEN 0.30::DOUBLE PRECISION WHEN pm.was_recently_used THEN 0.20::DOUBLE PRECISION ELSE 0.0::DOUBLE PRECISION END) AS rec_boost,
            pm.was_saved,
            pm.was_recently_used
        FROM place_metrics pm
        WHERE NOT v_has_query OR pm.raw_text_score > 0.20
    )
    SELECT
        sp.id,
        sp.name_ar,
        sp.name_en,
        sp.address_ar,
        sp.address_en,
        sp.category,
        sp.latitude,
        sp.longitude,
        sp.dist_meters,
        sp.dist_km,
        sp.text_score,
        sp.dist_score,
        sp.pop_score,
        sp.rec_boost,
        sp.was_saved,
        sp.was_recently_used,
        (
            CASE 
                WHEN v_has_query THEN
                    ((0.60 * sp.text_score) + (0.25 * sp.dist_score) + (0.10 * sp.pop_score) + (0.05 * sp.rec_boost))::DOUBLE PRECISION
                ELSE
                    ((0.70 * sp.dist_score) + (0.15 * sp.pop_score) + (0.15 * (CASE WHEN sp.was_saved THEN 1.0 WHEN sp.was_recently_used THEN 0.7 ELSE 0.0 END)))::DOUBLE PRECISION
            END
        ) AS final_score
    FROM scored_places sp
    ORDER BY final_score DESC, sp.dist_meters ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- 7. RPC Function: Record Place Selection
CREATE OR REPLACE FUNCTION public.record_place_selection(
    p_user_id UUID DEFAULT NULL,
    p_place_id UUID DEFAULT NULL,
    p_place_name TEXT DEFAULT '',
    p_formatted_address TEXT DEFAULT '',
    p_latitude DOUBLE PRECISION DEFAULT 0,
    p_longitude DOUBLE PRECISION DEFAULT 0,
    p_query TEXT DEFAULT ''
)
RETURNS VOID AS $$
BEGIN
    -- Increment place popularity if registered place
    IF p_place_id IS NOT NULL THEN
        UPDATE public.places 
        SET popularity = popularity + 1, updated_at = NOW()
        WHERE id = p_place_id;
    END IF;

    -- Upsert to user search history if user is authenticated
    IF p_user_id IS NOT NULL AND p_place_name <> '' AND p_latitude <> 0 AND p_longitude <> 0 THEN
        UPDATE public.user_search_history
        SET search_count = search_count + 1,
            last_searched_at = NOW(),
            place_name = p_place_name,
            formatted_address = p_formatted_address,
            query = p_query
        WHERE user_id = p_user_id 
          AND (
            (place_id IS NOT NULL AND place_id = p_place_id)
            OR (abs(latitude - p_latitude) < 0.001 AND abs(longitude - p_longitude) < 0.001)
          );

        IF NOT FOUND THEN
            INSERT INTO public.user_search_history (
                user_id, place_id, query, place_name, formatted_address, latitude, longitude, search_count, last_searched_at
            )
            VALUES (
                p_user_id, p_place_id, p_query, p_place_name, p_formatted_address, p_latitude, p_longitude, 1, NOW()
            );
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- 8. Row Level Security (RLS)
ALTER TABLE public.places ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_saved_places ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_search_history ENABLE ROW LEVEL SECURITY;

-- Places: Public read access
DROP POLICY IF EXISTS "Public can view active places" ON public.places;
CREATE POLICY "Public can view active places" ON public.places
    FOR SELECT USING (is_active = TRUE);

-- Saved Places: User can view and manage their own saved places
DROP POLICY IF EXISTS "Users can view own saved places" ON public.user_saved_places;
CREATE POLICY "Users can view own saved places" ON public.user_saved_places
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own saved places" ON public.user_saved_places;
CREATE POLICY "Users can insert own saved places" ON public.user_saved_places
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own saved places" ON public.user_saved_places;
CREATE POLICY "Users can update own saved places" ON public.user_saved_places
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own saved places" ON public.user_saved_places;
CREATE POLICY "Users can delete own saved places" ON public.user_saved_places
    FOR DELETE USING (auth.uid() = user_id);

-- Search History: User can view and manage their own search history
DROP POLICY IF EXISTS "Users can view own search history" ON public.user_search_history;
CREATE POLICY "Users can view own search history" ON public.user_search_history
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own search history" ON public.user_search_history;
CREATE POLICY "Users can insert own search history" ON public.user_search_history
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own search history" ON public.user_search_history;
CREATE POLICY "Users can update own search history" ON public.user_search_history
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own search history" ON public.user_search_history;
CREATE POLICY "Users can delete own search history" ON public.user_search_history
    FOR DELETE USING (auth.uid() = user_id);

-- 9. Comprehensive Seed Data (Egypt: Sadat City, Menoufia, Cairo, Giza, October, New Cairo, Alex)
INSERT INTO public.places (name_ar, name_en, address_ar, address_en, category, latitude, longitude, aliases, popularity)
VALUES
    -- Sadat City (مدينة السادات)
    ('جامعة مدينة السادات', 'University of Sadat City', 'المنطقة الرابعة، مدينة السادات، المنوفية', 'Zone 4, Sadat City, Menoufia', 'university', 30.3732, 30.5058, ARRAY['جامعة السادات', 'Sadat University', 'رئاسة جامعة السادات'], 85),
    ('كلية الحاسبات والذكاء الاصطناعي - جامعة السادات', 'Faculty of Computers and AI - Sadat University', 'مدينة السادات، المنوفية', 'Sadat City, Menoufia', 'university', 30.3750, 30.5075, ARRAY['حاسبات السادات', 'FCI Sadat'], 70),
    ('كلية الصيدلة - جامعة مدينة السادات', 'Faculty of Pharmacy - Sadat University', 'مدينة السادات، المنوفية', 'Sadat City, Menoufia', 'university', 30.3725, 30.5042, ARRAY['صيدلة السادات', 'Pharmacy Sadat'], 65),
    ('كلية التجارة - جامعة مدينة السادات', 'Faculty of Commerce - Sadat University', 'مدينة السادات، المنوفية', 'Sadat City, Menoufia', 'university', 30.3710, 30.5030, ARRAY['تجارة السادات'], 60),
    ('كلية التربية - جامعة مدينة السادات', 'Faculty of Education - Sadat University', 'مدينة السادات، المنوفية', 'Sadat City, Menoufia', 'university', 30.3695, 30.5015, ARRAY['تربية السادات'], 55),
    ('كلية الحقوق - جامعة مدينة السادات', 'Faculty of Law - Sadat University', 'مدينة السادات، المنوفية', 'Sadat City, Menoufia', 'university', 30.3740, 30.5065, ARRAY['حقوق السادات'], 50),
    ('كلية السياحة والفنادق - جامعة السادات', 'Faculty of Tourism and Hotels - Sadat University', 'مدينة السادات، المنوفية', 'Sadat City, Menoufia', 'university', 30.3760, 30.5085, ARRAY['سياحة وفنادق السادات'], 45),
    ('مستشفى السادات المركزي', 'Sadat Central Hospital', 'المنطقة الأولى، مدينة السادات، المنوفية', 'Zone 1, Sadat City, Menoufia', 'hospital', 30.3798, 30.5140, ARRAY['مستشفى السادات العام', 'Sadat Hospital'], 75),
    ('مستشفى السادات التخصصي', 'Sadat Specialized Hospital', 'المنطقة السكنية الثالثة، مدينة السادات', 'Zone 3, Sadat City', 'hospital', 30.3820, 30.5180, ARRAY['المستشفى التخصصي بالسادات'], 50),
    ('موقف السادات العمومي', 'Sadat Public Bus Station', 'المدخل الرئيسي، مدينة السادات', 'Main Entrance, Sadat City', 'station', 30.3850, 30.5220, ARRAY['موقف السادات', 'محطة أوتوبيس السادات', 'موقف ميكروباص السادات'], 90),
    ('جهاز مدينة السادات', 'Sadat City Development Authority', 'المنطقة الأولى، مدينة السادات', 'Zone 1, Sadat City', 'government', 30.3785, 30.5120, ARRAY['مجلس مدينة السادات', 'جهاز السادات'], 60),
    ('سوق الجملة - مدينة السادات', 'Sadat Wholesale Market', 'المنطقة الحادية عشرة، مدينة السادات', 'Zone 11, Sadat City', 'store', 30.3650, 30.4950, ARRAY['سوق الخضار السادات', 'سوق الجملة'], 40),
    ('المنطقة الصناعية الأولى بالسادات', 'First Industrial Zone - Sadat City', 'المنطقة الصناعية، مدينة السادات', 'Industrial Zone, Sadat City', 'landmark', 30.3950, 30.4850, ARRAY['مصانع السادات', 'صناعية السادات'], 65),
    ('مول سفن ستارز السادات', 'Seven Stars Mall Sadat', 'المنطقة الخامسة، مدينة السادات', 'Zone 5, Sadat City', 'mall', 30.3755, 30.5105, ARRAY['مول 7 ستارز', 'Seven Stars'], 55),
    ('كارفور ماركت - السادات', 'Carrefour Market - Sadat City', 'المنطقة السكنية الرابعة، مدينة السادات', 'Zone 4, Sadat City', 'store', 30.3745, 30.5090, ARRAY['كارفور', 'Carrefour Sadat', 'هايبر كارفور السادات'], 75),

    -- Menoufia (المنوفية - شبين الكوم والمدن الرئيسية)
    ('جامعة المنوفية', 'Menoufia University', 'شارع جمال عبد الناصر، شبين الكوم، المنوفية', 'Gamal Abdel Nasser St, Shibin El Kom, Menoufia', 'university', 30.5583, 31.0094, ARRAY['رئاسة جامعة المنوفية', 'Menoufia University'], 80),
    ('مجمع كليات جامعة المنوفية', 'Menoufia University Campus', 'شبين الكوم، المنوفية', 'Shibin El Kom, Menoufia', 'university', 30.5620, 31.0150, ARRAY['مجمع الكليات شبين الكوم', 'كليات شبين'], 75),
    ('مستشفى العربي - أشمون', 'Al Arabi Hospital - Ashmoun', 'طريق مصر الإسكندرية الزراعي، أشمون، المنوفية', 'Ashmoun, Menoufia', 'hospital', 30.3250, 31.1150, ARRAY['مستشفى العربي', 'مستشفى توشيبا العربي', 'Al Arabi Hospital'], 85),
    ('مستشفى شبين الكوم التعليمي', 'Shibin El Kom Educational Hospital', 'شبين الكوم، المنوفية', 'Shibin El Kom, Menoufia', 'hospital', 30.5550, 31.0050, ARRAY['المستشفى التعليمي شبين'], 65),
    ('موقف شبين الكوم المجمع', 'Shibin El Kom Central Station', 'شبين الكوم، المنوفية', 'Shibin El Kom, Menoufia', 'station', 30.5650, 31.0200, ARRAY['موقف شبين الكوم', 'موقف شبين'], 70),

    -- Cairo (القاهرة)
    ('ميدان التحرير', 'Tahrir Square', 'وسط البلد، القاهرة', 'Downtown, Cairo', 'landmark', 30.0444, 31.2357, ARRAY['التحرير', 'Tahrir', 'ميدان التحرير وسط البلد'], 100),
    ('جامعة القاهرة', 'Cairo University', 'شارع الجامعة، الجيزة / القاهرة', 'University St, Giza', 'university', 30.0276, 31.2101, ARRAY['Cairo University', 'جامعة القاهرة بالجيزة'], 95),
    ('جامعة عين شمس', 'Ain Shams University', 'العباسية، القاهرة', 'Abbassia, Cairo', 'university', 30.0772, 31.2850, ARRAY['Ain Shams University', 'عين شمس'], 85),
    ('الجامعة الأمريكية بالقاهرة (AUC)', 'American University in Cairo (AUC)', 'التجمع الخامس، القاهرة الجديدة', 'Fifth Settlement, New Cairo', 'university', 30.0263, 31.4913, ARRAY['الجامعة الأمريكية', 'AUC', 'American University'], 90),
    ('الجامعة الألمانية بالقاهرة (GUC)', 'German University in Cairo (GUC)', 'التجمع الخامس، القاهرة الجديدة', 'Fifth Settlement, New Cairo', 'university', 29.9868, 31.4414, ARRAY['الجامعة الألمانية', 'GUC', 'German University'], 85),
    ('مطار القاهرة الدولي', 'Cairo International Airport', 'مصر الجديدة، طريق المطار، القاهرة', 'Airport Rd, Heliopolis, Cairo', 'airport', 30.1219, 31.4056, ARRAY['المطار', 'Cairo Airport', 'صالة 1', 'صالة 2', 'صالة 3'], 100),
    ('محطة قطار رمسيس (محطة مصر)', 'Ramses Railway Station', 'ميدان رمسيس، القاهرة', 'Ramses Square, Cairo', 'station', 30.0633, 31.2467, ARRAY['محطة رمسيس', 'محطة مصر', 'Ramses Station'], 95),
    ('سيتي ستارز مول', 'Citystars Mall', 'شارع عمر بن الخطاب، مدينة نصر، القاهرة', 'Nasr City, Cairo', 'mall', 30.0730, 31.3458, ARRAY['سيتي ستارز', 'Citystars', 'City Stars'], 90),
    ('كايرو فيستيفال سيتي مول', 'Cairo Festival City Mall (CFC)', 'التجمع الخامس، الطريق الدائري، القاهرة الجديدة', 'New Cairo', 'mall', 30.0298, 31.4082, ARRAY['كايرو فيستيفال', 'CFC', 'Cairo Festival City'], 95),
    ('سيتي سنتر ألماظة', 'City Centre Almaza', 'طريق السويس، مصر الجديدة، القاهرة', 'Suez Rd, Heliopolis, Cairo', 'mall', 30.0880, 31.3650, ARRAY['مول ألماظة', 'City Centre Almaza'], 80),
    ('كارفور المعادي (دائري المعادي)', 'Carrefour Maadi', 'الطريق الدائري، المعادي، القاهرة', 'Ring Road, Maadi, Cairo', 'store', 29.9780, 31.3060, ARRAY['كارفور المعادي', 'Carrefour Maadi', 'سيتي سنتر المعادي'], 85),
    ('مستشفى القصر العيني', 'Kasr Al Ainy Hospital', 'شارع القصر العيني، القاهرة', 'Kasr Al Ainy St, Cairo', 'hospital', 30.0305, 31.2285, ARRAY['القصر العيني', 'مستشفى قصر العيني الفرنساوي'], 85),
    ('مستشفى 57357 لعلاج سرطان الأطفال', 'Children Cancer Hospital 57357', 'شارع سكة الإمام، السيدة زينب، القاهرة', 'Sayeda Zeinab, Cairo', 'hospital', 30.0210, 31.2370, ARRAY['57357', 'مستشفى 57357'], 80),
    ('برج القاهرة', 'Cairo Tower', 'الجزيرة، الزمالك، القاهرة', 'Zamalek, Cairo', 'landmark', 30.0459, 31.2243, ARRAY['البرج', 'Cairo Tower'], 85),
    ('خان الخليلي', 'Khan el-Khalili', 'الحسين، القاهرة التاريخية، القاهرة', 'El Gamaleya, Cairo', 'landmark', 30.0478, 31.2622, ARRAY['الحسين', 'خان الخليلي'], 80),

    -- Giza & 6th of October (الجيزة و 6 أكتوبر)
    ('أهرامات الجيزة', 'Giza Pyramids', 'الهرم، الجيزة', 'Al Haram, Giza', 'landmark', 29.9792, 31.1342, ARRAY['الأهرامات', 'Pyramids', 'أهرام الجيزة'], 95),
    ('شارع النيل - الجيزة', 'El Nile Street - Giza', 'الدقي / العجوزة، الجيزة', 'Dokki, Giza', 'landmark', 30.0130, 31.2080, ARRAY['شارع النيل', 'كورنيش النيل الجيزة'], 75),
    ('شارع جامعة الدول العربية', 'Gamet El Dewal El Arabia St', 'المهندسين، الجيزة', 'Mohandessin, Giza', 'landmark', 30.0526, 31.2014, ARRAY['جامعة الدول', 'المهندسين'], 80),
    ('ميدان لبنان', 'Lebanon Square', 'المهندسين، الجيزة', 'Mohandessin, Giza', 'landmark', 30.0620, 31.1980, ARRAY['ميدان لبنان المهندسين'], 75),
    ('مول مصر', 'Mall of Egypt', 'طريق الواحات، مدينة 6 أكتوبر، الجيزة', 'Al Wahat Rd, 6th of October', 'mall', 29.9722, 31.0152, ARRAY['مول مصر', 'Mall of Egypt', 'سكي مصر'], 95),
    ('مول العرب', 'Mall of Arabia', 'ميدان جهينة، طريق المحور، 6 أكتوبر، الجيزة', 'Juhayna Sq, 6th of October', 'mall', 30.0075, 30.9735, ARRAY['مول العرب', 'Mall of Arabia'], 95),
    ('جامعة 6 أكتوبر', 'October 6 University (O6U)', 'المحور المركزي، 6 أكتوبر، الجيزة', 'Central Axis, 6th of October', 'university', 29.9750, 30.9430, ARRAY['جامعة أكتوبر', 'O6U', 'October 6 University'], 85),
    ('جامعة مصر للعلوم والتكنولوجيا (MUST)', 'Misr University for Science and Technology (MUST)', 'طريق المحور، 6 أكتوبر، الجيزة', '6th of October', 'university', 29.9880, 30.9630, ARRAY['جامعة MUST', 'جامعة مصر', 'MUST'], 85),
    ('ميدان الحصري', 'Al Hosary Square', 'الحي السابع، 6 أكتوبر، الجيزة', '7th District, 6th of October', 'landmark', 29.9670, 30.9320, ARRAY['مسجد الحصري', 'الحصري', 'ميدان الحصري أكتوبر'], 90),
    ('مستشفى دار الفؤاد', 'Dar Al Fouad Hospital', 'طريق 26 يوليو، 6 أكتوبر، الجيزة', '26th of July Corridor, 6th of October', 'hospital', 30.0040, 30.9850, ARRAY['دار الفؤاد', 'Dar Al Fouad'], 80),
    ('هايبر وان - الشيخ زايد', 'Hyper One - Sheikh Zayed', 'مدخل الشيخ زايد، طريق مصر الإسكندرية الصحراوي', 'Sheikh Zayed, Giza', 'store', 30.0380, 31.0250, ARRAY['هايبر وان', 'Hyper One', 'هايبر الشيخ زايد'], 90),

    -- Alexandria (الإسكندرية)
    ('مكتبة الإسكندرية', 'Bibliotheca Alexandrina', 'الشاطبي، كورنيش الإسكندرية', 'Shatby, Alexandria', 'landmark', 31.2089, 29.9092, ARRAY['المكتبة', 'Alexandria Library', 'Bibliotheca'], 90),
    ('جامعة الإسكندرية', 'Alexandria University', 'الشاطبي، الإسكندرية', 'Shatby, Alexandria', 'university', 31.2050, 29.9150, ARRAY['Alexandria University', 'جامعة اسكندرية'], 85),
    ('محطة قطار سيدي جابر', 'Sidi Gaber Railway Station', 'سيدي جابر، الإسكندرية', 'Sidi Gaber, Alexandria', 'station', 31.2180, 29.9420, ARRAY['محطة سيدي جابر', 'Sidi Gaber Station'], 85),
    ('محطة مصر بالإسكندرية', 'Alexandria Railway Station (Misr Station)', 'محطة مصر، العطارين، الإسكندرية', 'Alexandria', 'station', 31.1920, 29.9060, ARRAY['محطة مصر اسكندرية'], 80),
    ('مطار برج العرب الدولي', 'Borg El Arab International Airport', 'برج العرب، الإسكندرية', 'Borg El Arab, Alexandria', 'airport', 30.9177, 29.6964, ARRAY['مطار برج العرب', 'Borg El Arab Airport'], 85),
    ('سان ستيفانو جراند بلازا', 'San Stefano Grand Plaza', 'سان ستيفانو، كورنيش الإسكندرية', 'San Stefano, Alexandria', 'mall', 31.2435, 29.9650, ARRAY['سان ستيفانو', 'San Stefano Mall'], 85),
    ('سيتي سنتر الإسكندرية (كارفور)', 'City Centre Alexandria (Carrefour)', 'طريق مصر الإسكندرية الصحراوي، محرم بك', 'Alexandria', 'mall', 31.1550, 29.9320, ARRAY['كارفور اسكندرية', 'سيتي سنتر اسكندرية', 'Carrefour Alexandria'], 85)
ON CONFLICT DO NOTHING;
