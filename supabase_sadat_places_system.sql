-- =============================================================================
-- inRide: Sadat City Smart Geographic System & Expandable Places Database
-- Focus: مدينة السادات – محافظة المنوفية – مصر
-- Covers 25 Categories: Supermarkets, Restaurants, Cafes, Pharmacies, Shops,
-- Workshops, Automotive, Gas Stations, Clinics, Schools, Malls, Banks, etc.
-- 100% Free Open Solution (Supabase PostgreSQL + OpenStreetMap)
-- =============================================================================

-- 1. Create / Extend the sadat_places table
CREATE TABLE IF NOT EXISTS public.sadat_places (
    id TEXT PRIMARY KEY,
    name_ar TEXT NOT NULL,
    name_en TEXT,
    normalized_name TEXT NOT NULL,
    aliases TEXT[] DEFAULT '{}',
    category TEXT NOT NULL DEFAULT 'general', -- 25 main categories
    sub_category TEXT,
    district TEXT,
    mall_name TEXT,
    phone TEXT,
    place_type TEXT NOT NULL DEFAULT 'commercial', -- residential_area, landmark, commercial, amenity, shop, etc.
    city TEXT NOT NULL DEFAULT 'مدينة السادات',
    address TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    geohash TEXT,
    source TEXT NOT NULL DEFAULT 'Verified_Partner',
    source_id TEXT,
    coordinates_verified BOOLEAN NOT NULL DEFAULT true,
    is_active BOOLEAN NOT NULL DEFAULT true,
    popularity_score INTEGER NOT NULL DEFAULT 80,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure newly added columns exist if table was previously created
ALTER TABLE public.sadat_places ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'general';
ALTER TABLE public.sadat_places ADD COLUMN IF NOT EXISTS sub_category TEXT;
ALTER TABLE public.sadat_places ADD COLUMN IF NOT EXISTS district TEXT;
ALTER TABLE public.sadat_places ADD COLUMN IF NOT EXISTS mall_name TEXT;
ALTER TABLE public.sadat_places ADD COLUMN IF NOT EXISTS phone TEXT;

-- 2. Create optimized indexes for instant search & geo queries
CREATE INDEX IF NOT EXISTS idx_sadat_places_normalized_name ON public.sadat_places (normalized_name);
CREATE INDEX IF NOT EXISTS idx_sadat_places_category ON public.sadat_places (category);
CREATE INDEX IF NOT EXISTS idx_sadat_places_district ON public.sadat_places (district);
CREATE INDEX IF NOT EXISTS idx_sadat_places_mall ON public.sadat_places (mall_name);
CREATE INDEX IF NOT EXISTS idx_sadat_places_place_type ON public.sadat_places (place_type);
CREATE INDEX IF NOT EXISTS idx_sadat_places_coords ON public.sadat_places (latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_sadat_places_active ON public.sadat_places (is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_sadat_places_aliases ON public.sadat_places USING GIN (aliases);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.sadat_places ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read access to active sadat_places" ON public.sadat_places;
CREATE POLICY "Allow public read access to active sadat_places"
ON public.sadat_places
FOR SELECT
USING (is_active = true);

DROP POLICY IF EXISTS "Allow authenticated service role to manage sadat_places" ON public.sadat_places;
CREATE POLICY "Allow authenticated service role to manage sadat_places"
ON public.sadat_places
FOR ALL
USING (auth.role() = 'service_role');

-- 4. Search RPC function with category intent recognition & Haversine distance ranking
CREATE OR REPLACE FUNCTION public.search_sadat_places(
    p_query TEXT,
    p_lat DOUBLE PRECISION DEFAULT 30.3789,
    p_lng DOUBLE PRECISION DEFAULT 30.5182,
    p_limit INTEGER DEFAULT 15
)
RETURNS TABLE (
    id TEXT,
    place_id TEXT,
    name_ar TEXT,
    name_en TEXT,
    place_name TEXT,
    formatted_address TEXT,
    category TEXT,
    sub_category TEXT,
    district TEXT,
    mall_name TEXT,
    phone TEXT,
    place_type TEXT,
    city TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    coordinates_verified BOOLEAN,
    distance_km DOUBLE PRECISION,
    popularity_score INTEGER,
    final_score DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_query TEXT;
BEGIN
    -- Basic Arabic normalization
    v_clean_query := TRIM(LOWER(p_query));
    v_clean_query := REGEXP_REPLACE(v_clean_query, '[إأآٱ]', 'ا', 'g');
    v_clean_query := REGEXP_REPLACE(v_clean_query, 'ة', 'ه', 'g');
    v_clean_query := REGEXP_REPLACE(v_clean_query, 'ى', 'ي', 'g');

    RETURN QUERY
    SELECT 
        sp.id,
        sp.id AS place_id,
        sp.name_ar,
        sp.name_en,
        sp.name_ar AS place_name,
        sp.address AS formatted_address,
        sp.category,
        sp.sub_category,
        sp.district,
        sp.mall_name,
        sp.phone,
        sp.place_type,
        sp.city,
        sp.latitude,
        sp.longitude,
        sp.coordinates_verified,
        -- Haversine distance in km
        (6371.0 * ACOS(
            LEAST(1.0, GREATEST(-1.0,
                COS(RADIANS(p_lat)) * COS(RADIANS(sp.latitude)) *
                COS(RADIANS(sp.longitude) - RADIANS(p_lng)) +
                SIN(RADIANS(p_lat)) * SIN(RADIANS(sp.latitude))
            ))
        )) AS distance_km,
        sp.popularity_score,
        -- Score calculation: name match + category match + mall match + proximity bonus + popularity
        (
            CASE 
                WHEN sp.normalized_name = v_clean_query OR v_clean_query = ANY(sp.aliases) THEN 100.0
                WHEN sp.normalized_name ILIKE v_clean_query || '%' THEN 90.0
                WHEN sp.category ILIKE '%' || v_clean_query || '%' OR sp.sub_category ILIKE '%' || v_clean_query || '%' THEN 85.0
                WHEN sp.mall_name ILIKE '%' || v_clean_query || '%' THEN 80.0
                WHEN sp.normalized_name ILIKE '%' || v_clean_query || '%' THEN 75.0
                WHEN sp.district ILIKE '%' || v_clean_query || '%' THEN 70.0
                ELSE 60.0
            END
            + GREATEST(0.0, 20.0 * (1.0 - ((6371.0 * ACOS(
                LEAST(1.0, GREATEST(-1.0,
                    COS(RADIANS(p_lat)) * COS(RADIANS(sp.latitude)) *
                    COS(RADIANS(sp.longitude) - RADIANS(p_lng)) +
                    SIN(RADIANS(p_lat)) * SIN(RADIANS(sp.latitude))
                ))
            )) / 25.0)))
            + (sp.popularity_score / 100.0) * 5.0
        ) AS final_score
    FROM public.sadat_places sp
    WHERE sp.is_active = true
      AND (
          sp.normalized_name ILIKE '%' || v_clean_query || '%'
          OR sp.category ILIKE '%' || v_clean_query || '%'
          OR sp.sub_category ILIKE '%' || v_clean_query || '%'
          OR sp.mall_name ILIKE '%' || v_clean_query || '%'
          OR sp.district ILIKE '%' || v_clean_query || '%'
          OR sp.address ILIKE '%' || v_clean_query || '%'
          OR EXISTS (
              SELECT 1 FROM UNNEST(sp.aliases) a WHERE a ILIKE '%' || v_clean_query || '%'
          )
      )
    ORDER BY final_score DESC, distance_km ASC
    LIMIT p_limit;
END;
$$;


-- =============================================================================
-- 5. Seed Data: Numbered Residential Zones, Landmarks & Municipal Districts
-- =============================================================================
-- 5. Seed Data: Numbered Zones 1 - 36, 14 Named Neighborhoods, & Special Sectors
-- =============================================================================

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, aliases, place_type, city, address, latitude, longitude, source, coordinates_verified, popularity_score
) VALUES
(
    'SDT_AREA_001', 'المنطقة 1', 'Zone 1', 'المنطقه 1', ARRAY['1','منطقة 1','المنطقة 1','المنطقه 1','منطقة1','حي 1','الحي 1','المنطقة الأولى','المنطقه الأولى','الأولى','الأول'],
    'residential_area', 'مدينة السادات', 'المنطقة الأولى، مدينة السادات، المنوفية', 30.36622, 30.50293,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_002', 'المنطقة 2', 'Zone 2', 'المنطقه 2', ARRAY['2','منطقة 2','المنطقة 2','المنطقه 2','منطقة2','حي 2','الحي 2','المنطقة الثانية','المنطقه الثانية','الثانية','الثاني'],
    'residential_area', 'مدينة السادات', 'المنطقة الثانية، مدينة السادات، المنوفية', 30.36119, 30.50992,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_003', 'المنطقة 3', 'Zone 3', 'المنطقه 3', ARRAY['3','منطقة 3','المنطقة 3','المنطقه 3','منطقة3','حي 3','الحي 3','المنطقة الثالثة','المنطقه الثالثة','الثالثة','الثالث'],
    'residential_area', 'مدينة السادات', 'المنطقة الثالثة، مدينة السادات، المنوفية', 30.37065, 30.50948,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_004', 'المنطقة 4', 'Zone 4', 'المنطقه 4', ARRAY['4','منطقة 4','المنطقة 4','المنطقه 4','منطقة4','حي 4','الحي 4','المنطقة الرابعة','المنطقه الرابعة','الرابعة','الرابع'],
    'residential_area', 'مدينة السادات', 'المنطقة الرابعة، مدينة السادات، المنوفية', 30.36453, 30.51472,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_005', 'المنطقة 5', 'Zone 5', 'المنطقه 5', ARRAY['5','منطقة 5','المنطقة 5','المنطقه 5','منطقة5','حي 5','الحي 5','المنطقة الخامسة','المنطقه الخامسة','الخامسة','الخامس'],
    'residential_area', 'مدينة السادات', 'المنطقة الخامسة، مدينة السادات، المنوفية', 30.37376, 30.49261,
    'OpenStreetMap', true, 99
),
(
    'SDT_AREA_006', 'المنطقة 6', 'Zone 6', 'المنطقه 6', ARRAY['6','منطقة 6','المنطقة 6','المنطقه 6','منطقة6','حي 6','الحي 6','المنطقة السادسة','المنطقه السادسة','السادسة','السادس'],
    'residential_area', 'مدينة السادات', 'المنطقة السادسة، مدينة السادات، المنوفية', 30.37964, 30.49866,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_007', 'المنطقة 7', 'Zone 7', 'المنطقه 7', ARRAY['7','منطقة 7','المنطقة 7','المنطقه 7','منطقة7','حي 7','الحي 7','المنطقة السبعة','المنطقه السبعة','السبعة','السابع'],
    'residential_area', 'مدينة السادات', 'المنطقة السبعة، مدينة السادات، المنوفية', 30.37344, 30.51548,
    'OpenStreetMap', true, 99
),
(
    'SDT_AREA_008', 'المنطقة 8', 'Zone 8', 'المنطقه 8', ARRAY['8','منطقة 8','المنطقة 8','المنطقه 8','منطقة8','حي 8','الحي 8','المنطقة الثامنة','المنطقه الثامنة','الثامنة','الثامن'],
    'residential_area', 'مدينة السادات', 'المنطقة الثامنة، مدينة السادات، المنوفية', 30.36771, 30.52049,
    'OpenStreetMap', true, 99
),
(
    'SDT_AREA_009', 'المنطقة 9', 'Zone 9', 'المنطقه 9', ARRAY['9','منطقة 9','المنطقة 9','المنطقه 9','منطقة9','حي 9','الحي 9','المنطقة التاسعة','المنطقه التاسعة','التاسعة','التاسع'],
    'residential_area', 'مدينة السادات', 'المنطقة التاسعة، مدينة السادات، المنوفية', 30.37788, 30.52088,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_010', 'المنطقة 10', 'Zone 10', 'المنطقه 10', ARRAY['10','منطقة 10','المنطقة 10','المنطقه 10','منطقة10','حي 10','الحي 10','المنطقة العاشرة','المنطقه العاشرة','العاشرة','العاشر'],
    'residential_area', 'مدينة السادات', 'المنطقة العاشرة، مدينة السادات، المنوفية', 30.37315, 30.5277,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_011', 'المنطقة 11', 'Zone 11', 'المنطقه 11', ARRAY['11','منطقة 11','المنطقة 11','المنطقه 11','منطقة11','حي 11','الحي 11','المنطقة الحادية عشرة','المنطقه الحادية عشرة','الحادية عشرة','الحادي عشر'],
    'residential_area', 'مدينة السادات', 'المنطقة الحادية عشرة، مدينة السادات، المنوفية', 30.36332, 30.52552,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_012', 'المنطقة 12', 'Zone 12', 'المنطقه 12', ARRAY['12','منطقة 12','المنطقة 12','المنطقه 12','منطقة12','حي 12','الحي 12','المنطقة الثانية عشرة','المنطقه الثانية عشرة','الثانية عشرة','الثاني عشر'],
    'residential_area', 'مدينة السادات', 'المنطقة الثانية عشرة، مدينة السادات، المنوفية', 30.3677, 30.53246,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_013', 'المنطقة 13', 'Zone 13', 'المنطقه 13', ARRAY['13','منطقة 13','المنطقة 13','المنطقه 13','منطقة13','حي 13','الحي 13','المنطقة الثالثة عشرة','المنطقه الثالثة عشرة','الثالثة عشرة','الثالث عشر'],
    'residential_area', 'مدينة السادات', 'المنطقة الثالثة عشرة، مدينة السادات، المنوفية', 30.38327, 30.50348,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_014', 'المنطقة 14', 'Zone 14', 'المنطقه 14', ARRAY['14','منطقة 14','المنطقة 14','المنطقه 14','منطقة14','حي 14','الحي 14','المنطقة الرابعة عشرة','المنطقه الرابعة عشرة','الرابعة عشرة','الرابع عشر'],
    'residential_area', 'مدينة السادات', 'المنطقة الرابعة عشرة، مدينة السادات، المنوفية', 30.38875, 30.50962,
    'OpenStreetMap', true, 99
),
(
    'SDT_AREA_015', 'المنطقة 15', 'Zone 15', 'المنطقه 15', ARRAY['15','منطقة 15','المنطقة 15','المنطقه 15','منطقة15','حي 15','الحي 15','المنطقة الخامسة عشرة','المنطقه الخامسة عشرة','الخامسة عشرة','الخامس عشر'],
    'residential_area', 'مدينة السادات', 'المنطقة الخامسة عشرة، مدينة السادات، المنوفية', 30.38261, 30.52506,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_016', 'المنطقة 16', 'Zone 16', 'المنطقه 16', ARRAY['16','منطقة 16','المنطقة 16','المنطقه 16','منطقة16','حي 16','الحي 16','المنطقة السادسة عشرة','المنطقه السادسة عشرة','السادسة عشرة','السادس عشر'],
    'residential_area', 'مدينة السادات', 'المنطقة السادسة عشرة، مدينة السادات، المنوفية', 30.37736, 30.53103,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_017', 'المنطقة 17', 'Zone 17', 'المنطقه 17', ARRAY['17','منطقة 17','المنطقة 17','المنطقه 17','منطقة17','حي 17','الحي 17','المنطقة السابعة عشرة','المنطقه السابعة عشرة','السابعة عشرة','السابع عشر'],
    'residential_area', 'مدينة السادات', 'المنطقة السابعة عشرة، مدينة السادات، المنوفية', 30.38866, 30.53048,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_018', 'المنطقة 18', 'Zone 18', 'المنطقه 18', ARRAY['18','منطقة 18','المنطقة 18','المنطقه 18','منطقة18','حي 18','الحي 18','المنطقة الثامنة عشرة','المنطقه الثامنة عشرة','الثامنة عشرة','الثامن عشر'],
    'residential_area', 'مدينة السادات', 'المنطقة الثامنة عشرة، مدينة السادات، المنوفية', 30.38279, 30.53667,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_019', 'المنطقة 19', 'Zone 19', 'المنطقه 19', ARRAY['19','منطقة 19','المنطقة 19','المنطقه 19','منطقة19','حي 19','الحي 19','المنطقة التاسعة عشرة','المنطقه التاسعة عشرة','التاسعة عشرة','التاسع عشر'],
    'residential_area', 'مدينة السادات', 'المنطقة التاسعة عشرة، مدينة السادات، المنوفية', 30.37238, 30.5369,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_020', 'المنطقة 20', 'Zone 20', 'المنطقه 20', ARRAY['20','منطقة 20','المنطقة 20','المنطقه 20','منطقة20','حي 20','الحي 20','المنطقة العشرون','المنطقه العشرون','العشرون','العشرين'],
    'residential_area', 'مدينة السادات', 'المنطقة العشرون، مدينة السادات، المنوفية', 30.37722, 30.54321,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_021', 'المنطقة 21', 'Zone 21', 'المنطقه 21', ARRAY['21','منطقة 21','المنطقة 21','المنطقه 21','منطقة21','حي 21','الحي 21','المنطقة الحادية والعشرون','المنطقه الحادية والعشرون','الحادية والعشرون','الحادي والعشرين'],
    'residential_area', 'مدينة السادات', 'المنطقة الحادية والعشرون، مدينة السادات، المنوفية', 30.39254, 30.5146,
    'OpenStreetMap', true, 99
),
(
    'SDT_AREA_022', 'المنطقة 22', 'Zone 22', 'المنطقه 22', ARRAY['22','منطقة 22','المنطقة 22','المنطقه 22','منطقة22','حي 22','الحي 22','المنطقة الثانية والعشرون','المنطقه الثانية والعشرون','الثانية والعشرون','الثاني والعشرين'],
    'residential_area', 'مدينة السادات', 'المنطقة الثانية والعشرون، مدينة السادات، المنوفية', 30.39882, 30.51923,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_023', 'المنطقة 23', 'Zone 23', 'المنطقه 23', ARRAY['23','منطقة 23','المنطقة 23','المنطقه 23','منطقة23','حي 23','الحي 23','المنطقة الثالثة والعشرون','المنطقه الثالثة والعشرون','الثالثة والعشرون','الثالث والعشرين'],
    'residential_area', 'مدينة السادات', 'المنطقة الثالثة والعشرون، مدينة السادات، المنوفية', 30.39199, 30.53506,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_024', 'المنطقة 24', 'Zone 24', 'المنطقه 24', ARRAY['24','منطقة 24','المنطقة 24','المنطقه 24','منطقة24','حي 24','الحي 24','المنطقة الرابعة والعشرون','المنطقه الرابعة والعشرون','الرابعة والعشرون','الرابع والعشرين'],
    'residential_area', 'مدينة السادات', 'المنطقة الرابعة والعشرون، مدينة السادات، المنوفية', 30.38562, 30.54161,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_025', 'المنطقة 25', 'Zone 25', 'المنطقه 25', ARRAY['25','منطقة 25','المنطقة 25','المنطقه 25','منطقة25','حي 25','الحي 25','المنطقة الخامسة والعشرون','المنطقه الخامسة والعشرون','الخامسة والعشرون','الخامس والعشرين'],
    'residential_area', 'مدينة السادات', 'المنطقة الخامسة والعشرون، مدينة السادات، المنوفية', 30.39733, 30.54125,
    'OpenStreetMap', true, 99
),
(
    'SDT_AREA_026', 'المنطقة 26', 'Zone 26', 'المنطقه 26', ARRAY['26','منطقة 26','المنطقة 26','المنطقه 26','منطقة26','حي 26','الحي 26','المنطقة السادسة والعشرون','المنطقه السادسة والعشرون','السادسة والعشرون','السادس والعشرين'],
    'residential_area', 'مدينة السادات', 'المنطقة السادسة والعشرون، مدينة السادات، المنوفية', 30.39117, 30.54513,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_027', 'المنطقة 27', 'Zone 27', 'المنطقه 27', ARRAY['27','منطقة 27','المنطقة 27','المنطقه 27','منطقة27','حي 27','الحي 27','المنطقة السابعة والعشرون','المنطقه السابعة والعشرون','السابعة والعشرون','السابع والعشرين'],
    'residential_area', 'مدينة السادات', 'المنطقة السابعة والعشرون، مدينة السادات، المنوفية', 30.38155, 30.54735,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_028', 'المنطقة 28', 'Zone 28', 'المنطقه 28', ARRAY['28','منطقة 28','المنطقة 28','المنطقه 28','منطقة28','حي 28','الحي 28','المنطقة الثامنة والعشرون','المنطقه الثامنة والعشرون','الثامنة والعشرون','الثامن والعشرين'],
    'residential_area', 'مدينة السادات', 'المنطقة الثامنة والعشرون، مدينة السادات، المنوفية', 30.38787, 30.55058,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_029', 'المنطقة 29', 'Zone 29', 'المنطقه 29', ARRAY['29','منطقة 29','المنطقة 29','المنطقه 29','منطقة29','حي 29','الحي 29','المنطقة التاسعة والعشرون','المنطقه التاسعة والعشرون','التاسعة والعشرون','التاسع والعشرين'],
    'residential_area', 'مدينة السادات', 'المنطقة التاسعة والعشرون، مدينة السادات، المنوفية', 30.40168, 30.52357,
    'OpenStreetMap', true, 99
),
(
    'SDT_AREA_030', 'المنطقة 30', 'Zone 30', 'المنطقه 30', ARRAY['30','منطقة 30','المنطقة 30','المنطقه 30','منطقة30','حي 30','الحي 30','المنطقة الثلاثون','المنطقه الثلاثون','الثلاثون','الثلاثين'],
    'residential_area', 'مدينة السادات', 'المنطقة الثلاثون، مدينة السادات، المنوفية', 30.40784, 30.52778,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_031', 'المنطقة 31', 'Zone 31', 'المنطقه 31', ARRAY['31','منطقة 31','المنطقة 31','المنطقه 31','منطقة31','حي 31','الحي 31','المنطقة الحادية والثلاثون','المنطقه الحادية والثلاثون','الحادية والثلاثون','الحادي والثلاثين'],
    'residential_area', 'مدينة السادات', 'المنطقة الحادية والثلاثون، مدينة السادات، المنوفية', 30.39663, 30.55179,
    'OpenStreetMap', true, 99
),
(
    'SDT_AREA_032', 'المنطقة 32', 'Zone 32', 'المنطقه 32', ARRAY['32','منطقة 32','المنطقة 32','المنطقه 32','منطقة32','حي 32','الحي 32','المنطقة الثانية والثلاثون','المنطقه الثانية والثلاثون','الثانية والثلاثون','الثاني والثلاثين'],
    'residential_area', 'مدينة السادات', 'المنطقة الثانية والثلاثون، مدينة السادات، المنوفية', 30.39154, 30.55741,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_033', 'المنطقة 33', 'Zone 33', 'المنطقه 33', ARRAY['33','منطقة 33','المنطقة 33','المنطقه 33','منطقة33','حي 33','الحي 33','المنطقة الثالثة والثلاثون','المنطقه الثالثة والثلاثون','الثالثة والثلاثون','الثالث والثلاثين'],
    'residential_area', 'مدينة السادات', 'المنطقة الثالثة والثلاثون، مدينة السادات، المنوفية', 30.40235, 30.55621,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_034', 'المنطقة 34', 'Zone 34', 'المنطقه 34', ARRAY['34','منطقة 34','المنطقة 34','المنطقه 34','منطقة34','حي 34','الحي 34','المنطقة الرابعة والثلاثون','المنطقه الرابعة والثلاثون','الرابعة والثلاثون','الرابع والثلاثين'],
    'residential_area', 'مدينة السادات', 'المنطقة الرابعة والثلاثون، مدينة السادات، المنوفية', 30.39657, 30.56219,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_035', 'المنطقة 35', 'Zone 35', 'المنطقه 35', ARRAY['35','منطقة 35','المنطقة 35','المنطقه 35','منطقة35','حي 35','الحي 35','المنطقة الخامسة والثلاثون','المنطقه الخامسة والثلاثون','الخامسة والثلاثون','الخامس والثلاثين'],
    'residential_area', 'مدينة السادات', 'المنطقة الخامسة والثلاثون، مدينة السادات، المنوفية', 30.40225, 30.54406,
    'OpenStreetMap', true, 90
),
(
    'SDT_AREA_036', 'المنطقة 36', 'Zone 36', 'المنطقه 36', ARRAY['36','منطقة 36','المنطقة 36','المنطقه 36','منطقة36','حي 36','الحي 36','المنطقة السادسة والثلاثون','المنطقه السادسة والثلاثون','السادسة والثلاثون','السادس والثلاثين'],
    'residential_area', 'مدينة السادات', 'المنطقة السادسة والثلاثون، مدينة السادات، المنوفية', 30.40634, 30.54979,
    'OpenStreetMap', true, 90
),
(
    'SDT_DIST_RAWDA', 'حي الروضة', 'Al Rawda District', 'حي الروضه', ARRAY['حي الروضة','الروضة','الروضه','منطقة الروضة','منطقه الروضه'],
    'neighborhood', 'مدينة السادات', 'حي الروضة، غرب المحور المركزي، مدينة السادات، المنوفية', 30.4009, 30.4857,
    'OpenStreetMap', true, 98
),
(
    'SDT_DIST_FARDOUS', 'حي الفردوس', 'Al Fardous District', 'حي الفردوس', ARRAY['حي الفردوس','الفردوس','منطقة الفردوس'],
    'neighborhood', 'مدينة السادات', 'حي الفردوس، شرق المحور المركزي، مدينة السادات، المنوفية', 30.3842, 30.5085,
    'OpenStreetMap', true, 98
),
(
    'SDT_DIST_NARJIS', 'حي النرجس', 'Al Narjis District', 'حي النرجس', ARRAY['حي النرجس','النرجس','منطقة النرجس'],
    'neighborhood', 'مدينة السادات', 'حي النرجس، بالقرب من المحور المركزي، مدينة السادات، المنوفية', 30.3792, 30.5125,
    'OpenStreetMap', true, 98
),
(
    'SDT_DIST_RAYHAN', 'حي الريحان', 'Al Rayhan District', 'حي الريحان', ARRAY['حي الريحان','الريحان','منطقة الريحان'],
    'neighborhood', 'مدينة السادات', 'حي الريحان، مدينة السادات، المنوفية', 30.3885, 30.514,
    'OpenStreetMap', true, 98
),
(
    'SDT_DIST_ZAYTOUN', 'حي الزيتون', 'Al Zaytoun District', 'حي الزيتون', ARRAY['حي الزيتون','الزيتون','منطقة الزيتون'],
    'neighborhood', 'مدينة السادات', 'حي الزيتون، جنوب المحور المركزي، مدينة السادات، المنوفية', 30.3715, 30.505,
    'OpenStreetMap', true, 98
),
(
    'SDT_DIST_BANAFSAJ', 'حي البنفسج', 'Al Banafsaj District', 'حي البنفسج', ARRAY['حي البنفسج','البنفسج','منطقة البنفسج'],
    'neighborhood', 'مدينة السادات', 'حي البنفسج، مدينة السادات، المنوفية', 30.386, 30.504,
    'OpenStreetMap', true, 98
),
(
    'SDT_DIST_NAKHEEL', 'حي النخيل', 'Al Nakheel District', 'حي النخيل', ARRAY['حي النخيل','النخيل','منطقة النخيل'],
    'neighborhood', 'مدينة السادات', 'حي النخيل، مدينة السادات، المنوفية', 30.392, 30.509,
    'OpenStreetMap', true, 98
),
(
    'SDT_DIST_KAWTHAR', 'حي الكوثر', 'Al Kawthar District', 'حي الكوثر', ARRAY['حي الكوثر','الكوثر','منطقة الكوثر'],
    'neighborhood', 'مدينة السادات', 'حي الكوثر، مدينة السادات، المنوفية', 30.368, 30.512,
    'OpenStreetMap', true, 98
),
(
    'SDT_DIST_ZOHOUR', 'حي الزهور', 'Al Zohour District', 'حي الزهور', ARRAY['حي الزهور','الزهور','منطقة الزهور'],
    'neighborhood', 'مدينة السادات', 'حي الزهور، بالقرب من المنطقة 7، مدينة السادات، المنوفية', 30.375, 30.518,
    'OpenStreetMap', true, 98
),
(
    'SDT_DIST_NOUR', 'حي النور', 'Al Nour District', 'حي النور', ARRAY['حي النور','النور','منطقة النور'],
    'neighborhood', 'مدينة السادات', 'حي النور، بالقرب من المنطقة 9، مدينة السادات، المنوفية', 30.381, 30.522,
    'OpenStreetMap', true, 98
),
(
    'SDT_DIST_ASHGAR', 'حي الأشجار', 'Al Ashgar District', 'حي الاشجار', ARRAY['حي الأشجار','الأشجار','الاشجار','منطقة الأشجار'],
    'neighborhood', 'مدينة السادات', 'حي الأشجار، شمال المنطقة 21، مدينة السادات، المنوفية', 30.395, 30.52,
    'OpenStreetMap', true, 98
),
(
    'SDT_DIST_YAQOUT', 'حي الياقوت', 'Al Yaqout District', 'حي الياقوت', ARRAY['حي الياقوت','الياقوت','منطقة الياقوت'],
    'neighborhood', 'مدينة السادات', 'حي الياقوت، بالقرب من المنطقة 18، مدينة السادات، المنوفية', 30.383, 30.533,
    'OpenStreetMap', true, 98
),
(
    'SDT_DIST_WOROUD', 'حي الورود', 'Al Woroud District', 'حي الورود', ARRAY['حي الورود','الورود','منطقة الورود'],
    'neighborhood', 'مدينة السادات', 'حي الورود، بالقرب من المنطقة 19، مدينة السادات، المنوفية', 30.378, 30.537,
    'OpenStreetMap', true, 98
),
(
    'SDT_DIST_MOTAMAYEZ', 'الحي المتميز (الحي المميز)', 'Al Motamayez District', 'الحي المتميز (الحي المميز)', ARRAY['الحي المتميز','الحي المميز','المتميز','المميز','حي المتميز','حي المميز'],
    'district', 'مدينة السادات', 'الحي المتميز، شمال المحور المركزي، مدينة السادات، المنوفية', 30.391, 30.518,
    'OpenStreetMap', true, 98
),
(
    'SDT_AREA_MOTAMAYEZ_STRIP', 'الشريط المميز', 'Motamayez Strip', 'الشريط المميز', ARRAY['الشريط المميز','الشريط المميز بالسادات','شريط متميز','شريط مميز'],
    'district', 'مدينة السادات', 'الشريط المميز، واجهة الحي المتميز على المحور، مدينة السادات', 30.3825, 30.5164,
    'OpenStreetMap', true, 95
),
(
    'SDT_AREA_GOLDEN_ZONE', 'المنطقة الذهبية (المربع الذهبي)', 'Golden Zone', 'المنطقه الذهبيه (المربع الذهبي)', ARRAY['المنطقة الذهبية','المنطقه الذهبيه','المربع الذهبي','المربع الذهبى'],
    'residential_area', 'مدينة السادات', 'المربع الذهبي، تقاطع المحور المركزي مع المتميز، مدينة السادات', 30.3845, 30.5175,
    'OpenStreetMap', true, 95
),
(
    'SDT_AREA_VILLAS', 'منطقة الفيلات', 'Villas Area', 'منطقه الفيلات', ARRAY['منطقة الفيلات','حي الفيلات','فيلات السادات','الفيلات'],
    'residential_area', 'مدينة السادات', 'منطقة الفيلات السكنية، الحي المتميز، مدينة السادات، المنوفية', 30.389, 30.517,
    'OpenStreetMap', true, 95
),
(
    'SDT_AREA_PARAMETER', 'البراميتر', 'Perimeter Road', 'البراميتر', ARRAY['البراميتر','براميتر','الباراميتر','طريق البراميتر'],
    'road', 'مدينة السادات', 'طريق البراميتر الدائري الجنوبي، مدينة السادات، المنوفية', 30.3585, 30.5164,
    'OpenStreetMap', true, 95
),
(
    'SDT_AREA_CENTRAL_AXIS', 'المحور المركزي', 'Central Axis Road', 'المحور المركزي', ARRAY['المحور المركزي','طريق المحور المركزي','شارع المحور المركزي'],
    'road', 'مدينة السادات', 'طريق المحور المركزي الرئيسي، مدينة السادات، المنوفية', 30.3755, 30.509,
    'OpenStreetMap', true, 95
),
(
    'SDT_AREA_BEIT_WATAN_A', 'بيت الوطن - المرحلة أ', 'Beit Al Watan Phase A', 'بيت الوطن - المرحله ا', ARRAY['بيت الوطن','بيت الوطن ا','مشروع بيت الوطن'],
    'residential_area', 'مدينة السادات', 'أراضي بيت الوطن المرحلة الأولى، مدينة السادات، المنوفية', 30.3741, 30.5061,
    'OpenStreetMap', true, 95
),
(
    'SDT_AREA_BEIT_WATAN_B', 'بيت الوطن - المرحلة ب', 'Beit Al Watan Phase B', 'بيت الوطن - المرحله ب', ARRAY['بيت الوطن ب','مشروع بيت الوطن ب'],
    'residential_area', 'مدينة السادات', 'أراضي بيت الوطن المرحلة الثانية، مدينة السادات، المنوفية', 30.3806, 30.5066,
    'OpenStreetMap', true, 95
),
(
    'SDT_AREA_EBNY_BETAK', 'مشروع ابني بيتك', 'Ebny Betak Project', 'مشروع ابني بيتك', ARRAY['ابني بيتك','ابنى بيتك','مشروع ابني بيتك','منطقة ابني بيتك'],
    'residential_area', 'مدينة السادات', 'منطقة ابني بيتك، بالقرب من المنطقة 19، مدينة السادات، المنوفية', 30.3745, 30.5367,
    'OpenStreetMap', true, 95
),
(
    'SDT_IND_001', 'المنطقة الصناعية الأولى', '1st Industrial Zone', 'المنطقه الصناعيه الاولي', ARRAY['المنطقة الصناعية الأولى','المنطقة الصناعية 1','صناعية 1','الصناعية الاولى'],
    'industrial_area', 'مدينة السادات', 'المنطقة الصناعية الأولى، مدينة السادات، المنوفية', 30.362, 30.548,
    'OpenStreetMap', true, 95
),
(
    'SDT_IND_DEVELOPERS', 'منطقة المطورين الصناعية', 'Developers Industrial Zone', 'منطقه المطورين الصناعيه', ARRAY['منطقة المطورين','المطورين الصناعية','المطورين السادات','المطورين'],
    'industrial_area', 'مدينة السادات', 'منطقة المطورين الصناعية المتكاملة، مدينة السادات، المنوفية', 30.375, 30.589,
    'OpenStreetMap', true, 95
)
ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    aliases = EXCLUDED.aliases,
    place_type = EXCLUDED.place_type,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    coordinates_verified = EXCLUDED.coordinates_verified,
    popularity_score = EXCLUDED.popularity_score,
    updated_at = NOW();


-- =============================================================================
-- 6. Seed Data: 25 Commercial, Healthcare, Retail & Services Categories
-- =============================================================================

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_001', 'هايبر شعلان - فرع المنطقة الأولى', 'Shaalan Hypermarket - Zone 1 Branch', 'هايبر شعلان - فرع المنطقه الاولي', 'supermarket', 'hypermarket', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.3664, 30.5031, true, true, 98, 'Verified_Partner', ARRAY['شعلان', 'سوبر ماركت شعلان', 'هايبر شعلان', 'ماركت شعلان', 'شعلان المنطقة الأولى', 'سوبر ماركت', 'سوبرماركت', 'ماركت', 'بقالة', 'هايبر', 'مواد غذائية']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_001_B', 'هايبر شعلان - فرع المحور المركزي', 'Shaalan Hypermarket - Central Axis Branch', 'هايبر شعلان - فرع المحور المركزي', 'supermarket', 'hypermarket', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور المركزي التجاري الجديد، أمام سيتي مول، مدينة السادات', 30.3682, 30.5061, true, true, 97, 'Verified_Partner', ARRAY['شعلان المحور', 'شعلان الجديد', 'هايبر شعلان المحور', 'شعلان', 'سوبر ماركت شعلان', 'سوبر ماركت', 'ماركت']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_002', 'سوبر ماركت زهران', 'Zahran Market', 'سوبر ماركت زهران', 'supermarket', 'supermarket', 'المنطقة الرابعة', 'مول زهران', 'commercial', 'مدينة السادات', 'مول زهران، سوق المنطقة الرابعة التجاري، مدينة السادات', 30.3804, 30.5158, true, true, 96, 'Verified_Partner', ARRAY['زهران', 'سوبر ماركت زهران', 'ماركت زهران', 'زهران ماركت', 'سوبر ماركت', 'سوبرماركت', 'ماركت', 'بقالة', 'مول زهران']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_003', 'سوبر ماركت خير زمان', 'Kheir Zaman Supermarket', 'سوبر ماركت خير زمان', 'supermarket', 'supermarket', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'محور الخدمات الرئيسي، المنطقة الأولى، مدينة السادات', 30.3688, 30.5052, true, true, 94, 'Verified_Partner', ARRAY['خير زمان', 'سوبر ماركت خير زمان', 'ماركت خير زمان', 'سوبر ماركت', 'ماركت', 'بقالة', 'مواد غذائية']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_004_A', 'سوبر ماركت الراية - فرع المنطقة 2', 'Al Raya Supermarket - Zone 2', 'سوبر ماركت الرايه - فرع المنطقه 2', 'supermarket', 'supermarket', 'المنطقة الثانية', NULL, 'commercial', 'مدينة السادات', 'شارع النصر، المنطقة السكنية الثانية، مدينة السادات', 30.3695, 30.5112, true, true, 92, 'Verified_Partner', ARRAY['الراية', 'ماركت الراية', 'سوبر ماركت الراية', 'الرايه', 'سوبر ماركت', 'بقالة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_004_B', 'سوبر ماركت الراية - فرع المنطقة 7', 'Al Raya Supermarket - Zone 7', 'سوبر ماركت الرايه - فرع المنطقه 7', 'supermarket', 'supermarket', 'المنطقة السابعة', NULL, 'commercial', 'مدينة السادات', 'شارع التجاريين، المنطقة السابعة، مدينة السادات', 30.3752, 30.5234, true, true, 91, 'Verified_Partner', ARRAY['الراية 7', 'ماركت الراية المنطقة السابعة', 'الراية', 'سوبر ماركت الراية']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_005', 'كارفور ماركت سيتي مول', 'Carrefour Market - City Mall', 'كارفور ماركت سيتي مول', 'supermarket', 'hypermarket', 'المحور المركزي', 'سيتي مول', 'commercial', 'مدينة السادات', 'الدور الأرضي، سيتي مول السادات، المحور المركزي، مدينة السادات', 30.3678, 30.5056, true, true, 97, 'Verified_Partner', ARRAY['كارفور', 'كارفور السادات', 'هايبر كارفور', 'سوبر ماركت كارفور', 'كارفور سيتي مول', 'سيتي مول', 'ماركت كارفور']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_006', 'سبينيس هايبر ماركت', 'Spinneys Hypermarket', 'سبينيس هايبر ماركت', 'supermarket', 'hypermarket', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور المركزي، أمام مجمع البنوك، مدينة السادات', 30.3691, 30.5075, true, true, 95, 'Verified_Partner', ARRAY['سبينيس', 'هايبر سبينيس', 'ماركت سبينيس', 'سوبر ماركت سبينيس', 'spinneys']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_007', 'فتح الله جملة ماركت', 'Fathalla Gomla Market', 'فتح الله جمله ماركت', 'supermarket', 'hypermarket', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور المركزي التجاري، مدينة السادات', 30.3705, 30.509, true, true, 94, 'Verified_Partner', ARRAY['فتح الله', 'جملة ماركت', 'فتح الله ماركت', 'سوبر ماركت فتح الله', 'هايبر فتح الله']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_008_A', 'كازيون ماركت - فرع المنطقة 1', 'Kazyon Market - Zone 1 Branch', 'كازيون ماركت - فرع المنطقه 1', 'supermarket', 'discount_store', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.3659, 30.5015, true, true, 95, 'Verified_Partner', ARRAY['كازيون', 'ماركت كازيون', 'سوبر ماركت كازيون', 'كازيون 1', 'كازيون المنطقة الأولى']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_008_B', 'كازيون ماركت - فرع سوق 4', 'Kazyon Market - Zone 4 Market', 'كازيون ماركت - فرع سوق 4', 'supermarket', 'discount_store', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'شارع السوق التجاري، المنطقة الرابعة، مدينة السادات', 30.3798, 30.5162, true, true, 95, 'Verified_Partner', ARRAY['كازيون سوق 4', 'كازيون المنطقة الرابعة', 'كازيون', 'ماركت كازيون']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_008_C', 'كازيون ماركت - فرع المنطقة 6', 'Kazyon Market - Zone 6 Branch', 'كازيون ماركت - فرع المنطقه 6', 'supermarket', 'discount_store', 'المنطقة السادسة', NULL, 'commercial', 'مدينة السادات', 'الشارع الرئيسي، المنطقة السادسة، مدينة السادات', 30.3721, 30.5189, true, true, 93, 'Verified_Partner', ARRAY['كازيون 6', 'كازيون المنطقة السادسة', 'كازيون', 'ماركت كازيون']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_008_D', 'كازيون ماركت - فرع المنطقة 11', 'Kazyon Market - Zone 11 Branch', 'كازيون ماركت - فرع المنطقه 11', 'supermarket', 'discount_store', 'المنطقة الحادية عشرة', NULL, 'commercial', 'مدينة السادات', 'المنطقة 11، بالقرب من مجمع الخدمات، مدينة السادات', 30.3842, 30.528, true, true, 92, 'Verified_Partner', ARRAY['كازيون 11', 'كازيون المنطقة الحادية عشرة', 'كازيون المنطقه 11', 'كازيون']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_008_E', 'كازيون ماركت - فرع المنطقة 12', 'Kazyon Market - Zone 12 Branch', 'كازيون ماركت - فرع المنطقه 12', 'supermarket', 'discount_store', 'المنطقة الثانية عشرة', NULL, 'commercial', 'مدينة السادات', 'محور الخدمات، المنطقة 12 (ابني بيتك)، مدينة السادات', 30.3891, 30.5342, true, true, 90, 'Verified_Partner', ARRAY['كازيون 12', 'كازيون ابني بيتك', 'كازيون المنطقة الثانية عشرة', 'كازيون']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_009_A', 'بيم ماركت - فرع المنطقة 2', 'BIM Market - Zone 2', 'بيم ماركت - فرع المنطقه 2', 'supermarket', 'discount_store', 'المنطقة الثانية', NULL, 'commercial', 'مدينة السادات', 'شارع أحمد عرابي، المنطقة الثانية، مدينة السادات', 30.3681, 30.5105, true, true, 93, 'Verified_Partner', ARRAY['بيم', 'ماركت بيم', 'بيم 2', 'بيم المنطقة الثانية', 'سوبر ماركت بيم']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_009_B', 'بيم ماركت - فرع المنطقة 3', 'BIM Market - Zone 3', 'بيم ماركت - فرع المنطقه 3', 'supermarket', 'discount_store', 'المنطقة الثالثة', NULL, 'commercial', 'مدينة السادات', 'شارع الزهور، المنطقة الثالثة، مدينة السادات', 30.3735, 30.5122, true, true, 92, 'Verified_Partner', ARRAY['بيم 3', 'بيم المنطقة الثالثة', 'بيم', 'ماركت بيم']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_009_C', 'بيم ماركت - فرع المنطقة 5', 'BIM Market - Zone 5', 'بيم ماركت - فرع المنطقه 5', 'supermarket', 'discount_store', 'المنطقة الخامسة', NULL, 'commercial', 'مدينة السادات', 'ميدان المنطقة الخامسة، مدينة السادات', 30.3768, 30.5145, true, true, 91, 'Verified_Partner', ARRAY['بيم 5', 'بيم المنطقة الخامسة', 'بيم', 'ماركت بيم']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_009_D', 'بيم ماركت - فرع المنطقة 7', 'BIM Market - Zone 7', 'بيم ماركت - فرع المنطقه 7', 'supermarket', 'discount_store', 'المنطقة السابعة', NULL, 'commercial', 'مدينة السادات', 'الشارع التجاري، المنطقة السابعة، مدينة السادات', 30.3748, 30.524, true, true, 91, 'Verified_Partner', ARRAY['بيم 7', 'بيم المنطقة السابعة', 'بيم', 'ماركت بيم']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_010', 'أولاد رجب ماركت', 'Awlad Ragab Market', 'اولاد رجب ماركت', 'supermarket', 'supermarket', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'بجوار مجمع المدارس، المنطقة الرابعة، مدينة السادات', 30.3785, 30.517, true, true, 92, 'Verified_Partner', ARRAY['اولاد رجب', 'أولاد رجب', 'سوبر ماركت اولاد رجب', 'ماركت اولاد رجب']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_011', 'أسواق المزرعة', 'Al Mazraah Supermarket', 'اسواق المزرعه', 'supermarket', 'supermarket', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'المنطقة الأولى، بجوار مركز الشباب، مدينة السادات', 30.367, 30.504, true, true, 90, 'Verified_Partner', ARRAY['المزرعة', 'اسواق المزرعة', 'ماركت المزرعة', 'سوبر ماركت المزرعة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_012', 'ماركت البركة', 'Al Baraka Market', 'ماركت البركه', 'supermarket', 'grocery', 'المنطقة السادسة', NULL, 'commercial', 'مدينة السادات', 'شارع مسجد النور، المنطقة السادسة، مدينة السادات', 30.3715, 30.5175, true, true, 88, 'Verified_Partner', ARRAY['البركة', 'ماركت البركة', 'بقالة البركة', 'سوبر ماركت']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_013', 'واحة الفواكه والخضار', 'Fruits & Vegetables Oasis', 'واحه الفواكه والخضار', 'supermarket', 'greengrocer', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.3662, 30.5025, true, true, 90, 'Verified_Partner', ARRAY['خضار', 'فاكهة', 'فواكه', 'محل خضار', 'خضري', 'فاكهاني', 'خضار وفاكهة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SUP_014', 'خضار وفاكهة الباشا', 'El Basha Vegetables & Fruits', 'خضار وفاكهه الباشا', 'supermarket', 'greengrocer', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق الخضار المركزي، المنطقة الرابعة، مدينة السادات', 30.3808, 30.5165, true, true, 91, 'Verified_Partner', ARRAY['خضار سوق 4', 'فاكهة سوق 4', 'الباشا خضار', 'خضار وفاكهة', 'خضري']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_001_A', 'مطعم البرنس - فرع سوق المنطقة الرابعة', 'El Prince Restaurant - Zone 4 Market', 'مطعم البرنس - فرع سوق المنطقه الرابعه', 'restaurant', 'grill', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة التجاري، مدينة السادات', 30.3802, 30.516, true, true, 98, 'Verified_Partner', ARRAY['البرنس', 'مطعم البرنس', 'مشويات البرنس', 'كبابجي البرنس', 'مشويات', 'كباب', 'كفتة', 'مطعم', 'اكل شرقي']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_001_B', 'مطعم البرنس - فرع المحور المركزي', 'El Prince Restaurant - Central Axis Branch', 'مطعم البرنس - فرع المحور المركزي', 'restaurant', 'grill', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور المركزي، بالقرب من سيتي مول، مدينة السادات', 30.3685, 30.5058, true, true, 97, 'Verified_Partner', ARRAY['البرنس المحور', 'مطعم البرنس الجديد', 'مشويات البرنس المحور', 'البرنس']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_002_A', 'مطعم الشبراوي - فرع المنطقة الأولى', 'El Shabrawy - Zone 1 Branch', 'مطعم الشبراوي - فرع المنطقه الاولي', 'restaurant', 'oriental_fast_food', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.3665, 30.5033, true, true, 97, 'Verified_Partner', ARRAY['الشبراوي', 'مطعم الشبراوي', 'شبراوي المنطقة الأولى', 'شبراوي', 'فول وطعمية', 'فول', 'طعمية', 'شاورما', 'فطار', 'مطعم']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_002_B', 'مطعم الشبراوي - فرع سوق المنطقة الرابعة', 'El Shabrawy - Zone 4 Market Branch', 'مطعم الشبراوي - فرع سوق المنطقه الرابعه', 'restaurant', 'oriental_fast_food', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'السوق التجاري، المنطقة الرابعة، مدينة السادات', 30.3795, 30.5155, true, true, 96, 'Verified_Partner', ARRAY['شبراوي سوق 4', 'الشبراوي المنطقة الرابعة', 'الشبراوي', 'شبراوي', 'فول وطعمية']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_003_A', 'كريب أند وافل - مول زهران', 'Crepe & Waffle - Zahran Mall', 'كريب اند وافل - مول زهران', 'restaurant', 'crepe_waffle', 'المنطقة الرابعة', 'مول زهران', 'commercial', 'مدينة السادات', 'مول زهران، سوق المنطقة الرابعة، مدينة السادات', 30.3805, 30.5159, true, true, 96, 'Verified_Partner', ARRAY['كريب اند وافل', 'كريب', 'وافل', 'كريب زهران', 'crepe and waffle', 'مطعم كريب', 'ساندوتشات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_003_B', 'كريب أند وافل - سيتي مول', 'Crepe & Waffle - City Mall Branch', 'كريب اند وافل - سيتي مول', 'restaurant', 'crepe_waffle', 'المحور المركزي', 'سيتي مول', 'commercial', 'مدينة السادات', 'فود كورت، سيتي مول السادات، المحور المركزي، مدينة السادات', 30.3679, 30.5057, true, true, 95, 'Verified_Partner', ARRAY['كريب سيتي مول', 'كريب اند وافل سيتي مول', 'كريب', 'وافل', 'crepe']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_004', 'مطعم أسماك السادات', 'Sadat Fish Restaurant', 'مطعم اسماك السادات', 'restaurant', 'seafood', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع المدارس، المنطقة الأولى، مدينة السادات', 30.3672, 30.5042, true, true, 95, 'Verified_Partner', ARRAY['اسماك السادات', 'أسماك السادات', 'سمك', 'اسماك', 'جمبري', 'مطعم سمك', 'ماكولات بحرية', 'فسفور']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_005', 'أسماك بحري والجمبري', 'Bahary Seafood & Shrimp', 'اسماك بحري والجمبري', 'restaurant', 'seafood', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة، مدينة السادات', 30.3801, 30.5168, true, true, 94, 'Verified_Partner', ARRAY['اسماك بحري', 'سمك بحري', 'اسماك سوق 4', 'سمك', 'جمبري', 'مطعم سمك']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_006', 'أسماك القنال', 'Al Canal Fish & Seafood', 'اسماك القنال', 'restaurant', 'seafood', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.3658, 30.5028, true, true, 93, 'Verified_Partner', ARRAY['القنال', 'اسماك القنال', 'سمك القنال', 'مطعم سمك']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_007', 'بيتزا كوين السادات', 'Pizza Queen Sadat', 'بيتزا كوين السادات', 'restaurant', 'pizza', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور المركزي، بجوار بنك مصر، مدينة السادات', 30.3687, 30.5065, true, true, 95, 'Verified_Partner', ARRAY['بيتزا كوين', 'بيتزا', 'pizza queen', 'فطير', 'كريب', 'ايطالي', 'مطعم بيتزا']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_008', 'بيتزا كينج السادات', 'Pizza King Sadat', 'بيتزا كينج السادات', 'restaurant', 'pizza', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'الشارع التجاري، المنطقة الرابعة، مدينة السادات', 30.3792, 30.5152, true, true, 93, 'Verified_Partner', ARRAY['بيتزا كينج', 'بيتزا', 'pizza king', 'مطعم بيتزا']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_009', 'دومينوز بيتزا', 'Domino''s Pizza Sadat', 'دومينوز بيتزا', 'restaurant', 'pizza', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور المركزي التجاري، مدينة السادات', 30.3684, 30.5059, true, true, 96, 'Verified_Partner', ARRAY['دومينوز', 'دومينوز بيتزا', 'dominos', 'pizza', 'بيتزا']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_010', 'بابا جونز بيتزا', 'Papa John''s Pizza', 'بابا جونز بيتزا', 'restaurant', 'pizza', 'المحور المركزي', 'سيتي مول', 'commercial', 'مدينة السادات', 'سيتي مول السادات، المحور المركزي، مدينة السادات', 30.3676, 30.5054, true, true, 95, 'Verified_Partner', ARRAY['بابا جونز', 'papa johns', 'بيتزا بابا جونز', 'بيتزا']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_011', 'بيتزا روما', 'Pizza Roma Sadat', 'بيتزا روما', 'restaurant', 'pizza', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.3661, 30.5029, true, true, 93, 'Verified_Partner', ARRAY['بيتزا روما', 'روما بيتزا', 'بيتزا', 'فطير وفطاطري']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_012', 'حاتي السادات للمشويات', 'Sadat Haty Grill', 'حاتي السادات للمشويات', 'restaurant', 'grill', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، أمام مجمع المصالح، المنطقة الأولى، مدينة السادات', 30.3667, 30.5036, true, true, 96, 'Verified_Partner', ARRAY['حاتي السادات', 'الحاتي', 'مشويات الحاتي', 'كبابجي', 'كباب وكفتة', 'مشويات', 'مطعم']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_013', 'حضرموت شيخ المندي', 'Hadramout Sheikh El Mandi', 'حضرموت شيخ المندي', 'restaurant', 'oriental_mandi', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور التجاري، مدينة السادات', 30.3693, 30.5071, true, true, 97, 'Verified_Partner', ARRAY['حضرموت', 'شيخ المندي', 'مندي', 'مظبي', 'كبسة', 'اكل يمني', 'لحم مندي', 'مطعم حضرموت']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_014', 'حضرموت عنتر السادات', 'Hadramout Antar Sadat', 'حضرموت عنتر السادات', 'restaurant', 'oriental_mandi', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'المنطقة الأولى، بجوار فندق أمون، مدينة السادات', 30.3654, 30.5021, true, true, 96, 'Verified_Partner', ARRAY['عنتر', 'حضرموت عنتر', 'مندي عنتر', 'مطعم عنتر', 'مندي']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_015', 'كبابجي المنوفي', 'El Menoufy Grill & Kebab', 'كبابجي المنوفي', 'restaurant', 'grill', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور المركزي، بالقرب من جهاز تنمية المدينة، مدينة السادات', 30.3689, 30.5068, true, true, 95, 'Verified_Partner', ARRAY['المنوفي', 'كبابجي المنوفي', 'مشويات المنوفي', 'كباب', 'كفتة', 'طرب']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_016', 'مطعم أهل الشام السوري', 'Ahl El Sham Syrian Restaurant', 'مطعم اهل الشام السوري', 'restaurant', 'syrian', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة، أمام مسجد الشهداء، مدينة السادات', 30.3807, 30.5163, true, true, 96, 'Verified_Partner', ARRAY['اهل الشام', 'أهل الشام', 'مطعم سوري', 'شاورما سوري', 'شاورما', 'فتة شاورما', 'بروستد', 'مناقيش']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_017', 'مطعم كرم الشام وروستو', 'Karam El Sham / Rosto Sadat', 'مطعم كرم الشام وروستو', 'restaurant', 'syrian', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور المركزي، بجوار سيتي مول، مدينة السادات', 30.3683, 30.5062, true, true, 97, 'Verified_Partner', ARRAY['كرم الشام', 'روستو', 'شاورما كرم الشام', 'مطعم سوري', 'شاورما فراخ', 'شاورما لحمة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_018', 'شاورما الريم', 'Al Reem Shawarma Sadat', 'شاورما الريم', 'restaurant', 'syrian', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة، مدينة السادات', 30.3799, 30.5158, true, true, 95, 'Verified_Partner', ARRAY['الريم', 'شاورما الريم', 'مطعم الريم', 'شاورما سوري']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_019', 'مطعم الدمشقي السوري', 'Al Dameshqi Restaurant', 'مطعم الدمشقي السوري', 'restaurant', 'syrian', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.3663, 30.5032, true, true, 94, 'Verified_Partner', ARRAY['الدمشقي', 'مطعم الدمشقي', 'شاورما دمشقي', 'اكل سوري']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_020_A', 'كشري الزعيم - فرع المنطقة الأولى', 'Koshary El Zaeem - Zone 1 Branch', 'كشري الزعيم - فرع المنطقه الاولي', 'restaurant', 'koshary', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.3668, 30.5037, true, true, 96, 'Verified_Partner', ARRAY['كشري الزعيم', 'الزعيم', 'كشري', 'طاجن', 'طواجن', 'مطعم كشري']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_020_B', 'كشري الزعيم - فرع سوق المنطقة الرابعة', 'Koshary El Zaeem - Zone 4 Market', 'كشري الزعيم - فرع سوق المنطقه الرابعه', 'restaurant', 'koshary', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة، مدينة السادات', 30.38, 30.5161, true, true, 95, 'Verified_Partner', ARRAY['كشري الزعيم سوق 4', 'الزعيم سوق 4', 'كشري', 'مطعم كشري']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_021', 'كشري التحرير', 'Koshary El Tahrir Sadat', 'كشري التحرير', 'restaurant', 'koshary', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.366, 30.5026, true, true, 95, 'Verified_Partner', ARRAY['كشري التحرير', 'التحرير', 'كشري', 'مطعم كشري']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_022', 'كشري هند', 'Koshary Hend Sadat', 'كشري هند', 'restaurant', 'koshary', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق 4 التجاري، مدينة السادات', 30.3794, 30.5153, true, true, 93, 'Verified_Partner', ARRAY['كشري هند', 'هند', 'كشري', 'طواجن']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_023', 'مطعم البغل السادات', 'El Baghl Restaurant Sadat', 'مطعم البغل السادات', 'restaurant', 'oriental_fast_food', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة، مدينة السادات', 30.3797, 30.5157, true, true, 95, 'Verified_Partner', ARRAY['البغل', 'مطعم البغل', 'فول البغل', 'فول وطعمية', 'فلافل']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_024', 'مطعم جاد السادات', 'Gad Restaurant Sadat', 'مطعم جاد السادات', 'restaurant', 'oriental_fast_food', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.3666, 30.5034, true, true, 94, 'Verified_Partner', ARRAY['جاد', 'مطعم جاد', 'فول وطعمية', 'فطير جاد', 'شاورما جاد']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_025', 'مطعم بازوكا فرايد تشيكن', 'Bazooka Fried Chicken Sadat', 'مطعم بازوكا فرايد تشيكن', 'restaurant', 'fast_food', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور المركزي التجاري، مدينة السادات', 30.3686, 30.5064, true, true, 97, 'Verified_Partner', ARRAY['بازوكا', 'فراخ بازوكا', 'برجر بازوكا', 'bazooka', 'fried chicken', 'بروستد', 'دجاج مقلي']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_026', 'مطعم زاكس السادات', 'Zaks Fried Chicken Sadat', 'مطعم زاكس السادات', 'restaurant', 'fast_food', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'المنطقة الأولى، بالقرب من مجمع المصالح، مدينة السادات', 30.3669, 30.5039, true, true, 95, 'Verified_Partner', ARRAY['زاكس', 'zaks', 'زاكس فرايد تشيكن', 'فراخ مقلية', 'برجر']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_027', 'مطعم هارت أتاك السادات', 'Heart Attack Restaurant Sadat', 'مطعم هارت اتاك السادات', 'restaurant', 'fast_food', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور التجاري، مدينة السادات', 30.369, 30.507, true, true, 96, 'Verified_Partner', ARRAY['هارت اتاك', 'هارت أتاك', 'heart attack', 'برجر', 'فرايد تشيكن', 'وجبات سريعة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_028', 'كنتاكي KFC السادات', 'KFC Sadat City', 'كنتاكي kfc السادات', 'restaurant', 'fast_food', 'مدخل السادات الصحراوي', NULL, 'commercial', 'مدينة السادات', 'محطة الوطنية، طريق القاهرة الإسكندرية الصحراوي، مدخل السادات', 30.345, 30.528, true, true, 97, 'Verified_Partner', ARRAY['كنتاكي', 'kfc', 'دجاج كنتاكي', 'فرايد تشيكن', 'وجبات سريعة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_029', 'ماكدونالدز McDonald''s', 'McDonald''s Sadat City', 'ماكدونالدز mcdonald''s', 'restaurant', 'fast_food', 'مدخل السادات الصحراوي', NULL, 'commercial', 'مدينة السادات', 'مجمع خدمات وطنية، طريق القاهرة الإسكندرية الصحراوي، مدخل السادات', 30.3452, 30.5285, true, true, 98, 'Verified_Partner', ARRAY['ماكدونالدز', 'ماك', 'mcdonalds', 'mcdonald', 'برجر', 'وجبات سريعة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_030', 'برجر كينج Burger King', 'Burger King Sadat', 'برجر كينج burger king', 'restaurant', 'fast_food', 'مدخل السادات الصحراوي', NULL, 'commercial', 'مدينة السادات', 'محطة شيل أوت ChillOut، مدخل السادات الصحراوي، مدينة السادات', 30.3475, 30.526, true, true, 96, 'Verified_Partner', ARRAY['برجر كينج', 'burger king', 'برجر', 'ساندوتشات برجر']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_031', 'بوفالو برجر السادات', 'Buffalo Burger Sadat', 'بوفالو برجر السادات', 'restaurant', 'burger', 'المحور المركزي', 'سيتي مول', 'commercial', 'مدينة السادات', 'سيتي مول السادات، الدور الأول، المحور المركزي، مدينة السادات', 30.3677, 30.5055, true, true, 96, 'Verified_Partner', ARRAY['بوفالو برجر', 'بافلو برجر', 'buffalo burger', 'برجر', 'سيتي مول']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_032', 'مطعم كوك دور', 'Cook Door Sadat', 'مطعم كوك دور', 'restaurant', 'fast_food', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.3662, 30.503, true, true, 95, 'Verified_Partner', ARRAY['كوك دور', 'cook door', 'ساندوتشات كوك دور', 'مطعم كوك دور']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_033', 'مطعم واحة السادات البدوي', 'Sadat Oasis Bedouin Restaurant', 'مطعم واحه السادات البدوي', 'restaurant', 'oriental_mandi', 'طريق الخدمات الصحراوي', NULL, 'commercial', 'مدينة السادات', 'طريق الخدمات، مدخل مدينة السادات، المنوفية', 30.352, 30.521, true, true, 95, 'Verified_Partner', ARRAY['واحة السادات', 'مطعم بدوي', 'مندي', 'مظبي', 'خروف مشوي', 'قعدة بدوية']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_034', 'حواوشي الأصلي', 'El Asly Hawawshi Sadat', 'حواوشي الاصلي', 'restaurant', 'hawawshi', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة، مدينة السادات', 30.3796, 30.5154, true, true, 92, 'Verified_Partner', ARRAY['حواوشي الاصلي', 'حواوشي', 'ساندوتشات حواوشي', 'مطعم حواوشي']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RST_035', 'مطعم طشة البيتي', 'Tashet Sadat Home Food', 'مطعم طشه البيتي', 'restaurant', 'oriental', 'المنطقة الثانية', NULL, 'commercial', 'مدينة السادات', 'المنطقة الثانية، بجوار صيدلية د. سامح، مدينة السادات', 30.369, 30.511, true, true, 91, 'Verified_Partner', ARRAY['طشة', 'طشه', 'اكل بيتي', 'محاشي', 'طواجن بيتي', 'وجبات بيتي']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CAF_001', 'ستاربكس Starbucks السادات', 'Starbucks Sadat City', 'ستاربكس starbucks السادات', 'cafe', 'coffee_shop', 'مدخل السادات الصحراوي', NULL, 'commercial', 'مدينة السادات', 'مجمع خدمات شيل أوت، مدخل مدينة السادات، طريق مصر إسكندرية الصحراوي', 30.3478, 30.5262, true, true, 98, 'Verified_Partner', ARRAY['ستاربكس', 'starbucks', 'ستار بكس', 'كافيه ستاربكس', 'قهوة ستاربكس', 'فرابوتشينو', 'ايس كوفي']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CAF_002', 'كوستا كوفي Costa Coffee', 'Costa Coffee Sadat', 'كوستا كوفي costa coffee', 'cafe', 'coffee_shop', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'محطة توتال إرجيز، المحور المركزي، مدينة السادات', 30.3692, 30.5078, true, true, 97, 'Verified_Partner', ARRAY['كوستا', 'كوستا كوفي', 'costa', 'costa coffee', 'كافيه كوستا', 'قهوة', 'اسبريسو']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CAF_003', 'بينوس كافيه سيتي مول', 'Beanos Cafe City Mall', 'بينوس كافيه سيتي مول', 'cafe', 'coffee_shop', 'المحور المركزي', 'سيتي مول', 'commercial', 'مدينة السادات', 'سيتي مول، المحور المركزي، مدينة السادات', 30.36785, 30.50565, true, true, 96, 'Verified_Partner', ARRAY['بينوس', 'beanos', 'كافيه بينوس', 'قهوة بينوس', 'سيتي مول']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CAF_004', 'جراند كافيه السادات', 'Grand Cafe Sadat', 'جراند كافيه السادات', 'cafe', 'lounge', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، أمام مستشفى السادات المركزي، مدينة السادات', 30.3666, 30.5035, true, true, 95, 'Verified_Partner', ARRAY['جراند كافيه', 'grand cafe', 'جراند', 'كافيه عائلي', 'مقهى', 'كافيه']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CAF_005', 'كافيه الروضة العائلي', 'Al Rawda Family Cafe', 'كافيه الروضه العائلي', 'cafe', 'family_cafe', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة، أمام مول زهران، مدينة السادات', 30.3803, 30.5157, true, true, 95, 'Verified_Partner', ARRAY['الروضة كافيه', 'كافيه الروضة', 'مقهى الروضة', 'كافيه سوق 4', 'شيشة', 'مشروبات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CAF_006', 'كوستا ريكا كافيه', 'Costa Rica Cafe', 'كوستا ريكا كافيه', 'cafe', 'coffee_shop', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور المركزي التجاري، مدينة السادات', 30.3684, 30.5063, true, true, 94, 'Verified_Partner', ARRAY['كوستاريكا', 'كوستا ريكا', 'costa rica', 'كافيه كوستا ريكا']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CAF_007', 'ليالي السادات لاونج', 'Layali Sadat Lounge', 'ليالي السادات لاونج', 'cafe', 'lounge', 'المنطقة الخامسة', NULL, 'commercial', 'مدينة السادات', 'الشارع الرئيسي، المنطقة الخامسة، مدينة السادات', 30.377, 30.5148, true, true, 93, 'Verified_Partner', ARRAY['ليالي السادات', 'كافيه ليالي السادات', 'لاونج', 'كافيه']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CAF_008', 'بونجورنو كافيه ومخبوزات', 'Buongiorno Cafe & Bakery', 'بونجورنو كافيه ومخبوزات', 'cafe', 'bakery_cafe', 'المنطقة السادسة', NULL, 'commercial', 'مدينة السادات', 'ميدان المنطقة السادسة، مدينة السادات', 30.3725, 30.5192, true, true, 92, 'Verified_Partner', ARRAY['بونجورنو', 'كافيه بونجورنو', 'buongiorno', 'كرواسون', 'قهوة ومخبوزات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CAF_009', 'كافيه السلطان', 'El Soltan Cafe', 'كافيه السلطان', 'cafe', 'traditional_cafe', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة، مدينة السادات', 30.3797, 30.5156, true, true, 92, 'Verified_Partner', ARRAY['السلطان', 'قهوة السلطان', 'كافيه السلطان', 'مقهى', 'قهوة بلدي', 'شاي']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CAF_010', 'كافيه ركن القهوة', 'Coffee Corner Sadat', 'كافيه ركن القهوه', 'cafe', 'coffee_shop', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'شارع الخدمات، المنطقة الرابعة، مدينة السادات', 30.3801, 30.5165, true, true, 93, 'Verified_Partner', ARRAY['ركن القهوة', 'coffee corner', 'كوفي كورنر', 'قهوة اسبريسو']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CAF_011', 'كافيه أروما', 'Aroma Cafe Sadat', 'كافيه اروما', 'cafe', 'coffee_shop', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.3664, 30.50315, true, true, 92, 'Verified_Partner', ARRAY['اروما', 'أروما', 'aroma cafe', 'كافيه اروما']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CAF_012', 'حلواني إيتوال Etoile', 'Etoile Pastry Sadat', 'حلواني ايتوال etoile', 'cafe', 'pastry_shop', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.36655, 30.50345, true, true, 98, 'Verified_Partner', ARRAY['ايتوال', 'إيتوال', 'etoile', 'حلواني ايتوال', 'تورتة', 'جاتوه', 'حلويات شرقية', 'بسبوسة', 'كنافة', 'حلاوة المولد']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CAF_013', 'حلواني العبد', 'El Abd Pastry Sadat', 'حلواني العبد', 'cafe', 'pastry_shop', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور المركزي التجاري، أمام سيتي مول، مدينة السادات', 30.3683, 30.506, true, true, 97, 'Verified_Partner', ARRAY['العبد', 'حلواني العبد', 'el abd', 'كحك العيد', 'بسكويت', 'حلويات العبد', 'ايس كريم']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CAF_014', 'حلواني لابوار', 'La Poire Pastry Sadat', 'حلواني لابوار', 'cafe', 'pastry_shop', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور المركزي التجاري، مدينة السادات', 30.3688, 30.5067, true, true, 96, 'Verified_Partner', ARRAY['لابوار', 'la poire', 'حلواني لابوار', 'تورت', 'شوكولاتة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CAF_015', 'حلواني شهد الملكة', 'Shahd El Maleka Pastry', 'حلواني شهد الملكه', 'cafe', 'pastry_shop', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة، أمام مول زهران، مدينة السادات', 30.3806, 30.5162, true, true, 95, 'Verified_Partner', ARRAY['شهد الملكة', 'حلواني شهد الملكة', 'تورتة', 'جاتوه', 'حلويات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CAF_016', 'عصائر فرغلي السادات', 'Farghaly Juices Sadat', 'عصائر فرغلي السادات', 'cafe', 'juice_bar', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.36635, 30.50315, true, true, 96, 'Verified_Partner', ARRAY['فرغلي', 'عصير فرغلي', 'عصائر', 'قصب', 'مانجو', 'كوكتيل', 'سموذي', 'محل عصير']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CAF_017', 'عصير تايم السادات', 'Juice Time Sadat', 'عصير تايم السادات', 'cafe', 'juice_bar', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة، مدينة السادات', 30.37995, 30.51585, true, true, 94, 'Verified_Partner', ARRAY['عصير تايم', 'juice time', 'عصير', 'ايس كريم', 'وافل وميلك شيك']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CAF_018', 'ألبان مكة', 'Mecca Dairy & Ice Cream', 'البان مكه', 'cafe', 'dairy_ice_cream', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة، مدينة السادات', 30.38025, 30.51615, true, true, 95, 'Verified_Partner', ARRAY['البان مكة', 'ألبان مكة', 'زبادي', 'لبن', 'ارز بلبن', 'ايس كريم', 'قشطة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_PHM_001_A', 'صيدلية العزبي - فرع المنطقة الأولى', 'El Ezaby Pharmacy - Zone 1 Branch', 'صيدليه العزبي - فرع المنطقه الاولي', 'pharmacy', 'chain_pharmacy', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'شارع جمال عبد الناصر، أمام بنك مصر، المنطقة الأولى، مدينة السادات', 30.3663, 30.503, true, true, 98, 'Verified_Partner', ARRAY['العزبي', 'صيدلية العزبي', 'صيدلية', 'دواء', 'ادوية', 'روشتة', 'مستحضرات تجميل', 'عزبي']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_PHM_001_B', 'صيدلية العزبي - فرع شيل أوت الصحراوي', 'El Ezaby Pharmacy - ChillOut Desert Road Branch', 'صيدليه العزبي - فرع شيل اوت الصحراوي', 'pharmacy', 'chain_pharmacy', 'مدخل السادات الصحراوي', NULL, 'amenity', 'مدينة السادات', 'محطة شيل أوت، طريق القاهرة الإسكندرية الصحراوي، مدخل السادات', 30.3476, 30.5261, true, true, 97, 'Verified_Partner', ARRAY['العزبي الصحراوي', 'صيدلية العزبي شيل اوت', 'العزبي', 'صيدلية']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_PHM_002_A', 'صيدلية سيف - فرع سوق 4', 'Seif Pharmacy - Zone 4 Market', 'صيدليه سيف - فرع سوق 4', 'pharmacy', 'chain_pharmacy', 'المنطقة الرابعة', NULL, 'amenity', 'مدينة السادات', 'سوق المنطقة الرابعة، أمام مول زهران، مدينة السادات', 30.38035, 30.51575, true, true, 97, 'Verified_Partner', ARRAY['صيدلية سيف', 'سيف', 'صيدلية', 'seif pharmacy', 'دواء']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_PHM_002_B', 'صيدلية سيف - سيتي مول', 'Seif Pharmacy - City Mall Branch', 'صيدليه سيف - سيتي مول', 'pharmacy', 'chain_pharmacy', 'المحور المركزي', 'سيتي مول', 'amenity', 'مدينة السادات', 'سيتي مول، المحور المركزي، مدينة السادات', 30.36775, 30.50555, true, true, 96, 'Verified_Partner', ARRAY['سيف سيتي مول', 'صيدلية سيف سيتي مول', 'صيدلية سيف', 'سيف']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_PHM_003', 'صيدليات مصر السادات', 'Misr Pharmacies Sadat', 'صيدليات مصر السادات', 'pharmacy', 'chain_pharmacy', 'المحور المركزي', NULL, 'amenity', 'مدينة السادات', 'المحور المركزي التجاري، مدينة السادات', 30.3687, 30.5066, true, true, 96, 'Verified_Partner', ARRAY['صيدليات مصر', 'مصر للصيدليات', 'صيدلية مصر', 'صيدلية', 'دواء']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_PHM_004', 'صيدلية 19011 السادات', '19011 Pharmacy Sadat', 'صيدليه 19011 السادات', 'pharmacy', 'chain_pharmacy', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.36645, 30.50325, true, true, 95, 'Verified_Partner', ARRAY['19011', 'صيدلية 19011', 'صيدلية']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_PHM_005', 'صيدلية د. أحمد عبد العزيز (24 ساعة)', 'Dr. Ahmed Abdelaziz 24/7 Pharmacy', 'صيدليه د. احمد عبد العزيز (24 ساعه)', 'pharmacy', 'community_pharmacy_24h', 'المنطقة الرابعة', NULL, 'amenity', 'مدينة السادات', 'سوق المنطقة الرابعة التجاري، مدينة السادات', 30.37985, 30.51595, true, true, 96, 'Verified_Partner', ARRAY['احمد عبد العزيز', 'صيدلية احمد عبد العزيز', 'صيدلية 24 ساعة', 'صيدلية طوارئ', 'دكتور احمد']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_PHM_006', 'صيدلية الأمل (24 ساعة)', 'Al Amal 24/7 Pharmacy', 'صيدليه الامل (24 ساعه)', 'pharmacy', 'community_pharmacy_24h', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'بجوار مستشفى السادات العام، المنطقة الأولى، مدينة السادات', 30.3671, 30.5041, true, true, 95, 'Verified_Partner', ARRAY['الامل', 'صيدلية الامل', 'صيدلية ٢٤ ساعة', 'صيدلية طوارئ مستشفى السادات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_PHM_007', 'صيدلية د. سامح', 'Dr. Sameh Pharmacy', 'صيدليه د. سامح', 'pharmacy', 'community_pharmacy', 'المنطقة الثانية', NULL, 'amenity', 'مدينة السادات', 'شارع النصر، المنطقة السكنية الثانية، مدينة السادات', 30.3692, 30.5108, true, true, 92, 'Verified_Partner', ARRAY['صيدلية سامح', 'دكتور سامح', 'صيدلية المنطقة الثانية']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_PHM_008', 'صيدلية د. محمود يونس', 'Dr. Mahmoud Younis Pharmacy', 'صيدليه د. محمود يونس', 'pharmacy', 'community_pharmacy', 'المنطقة السادسة', NULL, 'amenity', 'مدينة السادات', 'ميدان المنطقة السادسة، مدينة السادات', 30.3722, 30.5191, true, true, 92, 'Verified_Partner', ARRAY['محمود يونس', 'صيدلية محمود يونس', 'صيدلية المنطقة السادسة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_PHM_009', 'صيدلية النور', 'Al Nour Pharmacy', 'صيدليه النور', 'pharmacy', 'community_pharmacy', 'المنطقة الخامسة', NULL, 'amenity', 'مدينة السادات', 'المنطقة الخامسة، بجوار مول ريحانة، مدينة السادات', 30.3765, 30.5142, true, true, 91, 'Verified_Partner', ARRAY['صيدلية النور', 'النور', 'صيدلية المنطقة الخامسة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_PHM_010', 'صيدلية د. طارق', 'Dr. Tarek Pharmacy', 'صيدليه د. طارق', 'pharmacy', 'community_pharmacy', 'المنطقة الحادية عشرة', NULL, 'amenity', 'مدينة السادات', 'المنطقة 11، أمام كازيون ماركت، مدينة السادات', 30.3845, 30.5283, true, true, 90, 'Verified_Partner', ARRAY['صيدلية طارق', 'صيدلية المنطقة 11', 'صيدلية']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CLO_000', 'براند ستور ملابس رجالي', 'Brand Store Men Wear', 'براند ستور ملابس رجالي', 'clothing', 'menswear', 'المحور المركزي', 'سيتي مول', 'commercial', 'مدينة السادات', 'سيتي مول، الدور الأول، المحور المركزي، مدينة السادات', 30.36782, 30.50562, true, true, 96, 'Verified_Partner', ARRAY['براند ستور', 'براند ستور ملابس', 'ملابس رجالي', 'سيتي مول', 'محل ملابس']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CLO_001_A', 'تاون تيم - فرع المنطقة الأولى', 'Town Team - Zone 1 Branch', 'تاون تيم - فرع المنطقه الاولي', 'clothing', 'menswear', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.3664, 30.5031, true, true, 97, 'Verified_Partner', ARRAY['تاون تيم', 'town team', 'ملابس رجالي', 'قميص', 'بنطلون', 'بدلة', 'كاجوال', 'شوزات', 'محل ملابس']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CLO_001_B', 'تاون تيم - فرع سيتي مول', 'Town Team - City Mall Branch', 'تاون تيم - فرع سيتي مول', 'clothing', 'menswear', 'المحور المركزي', 'سيتي مول', 'commercial', 'مدينة السادات', 'الدور الأرضي، سيتي مول السادات، المحور المركزي، مدينة السادات', 30.3678, 30.5056, true, true, 96, 'Verified_Partner', ARRAY['تاون تيم سيتي مول', 'تاون تيم', 'town team', 'ملابس']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CLO_002', 'أكتيف أبو علاء Active', 'Active Abu Alaa City Mall', 'اكتيف ابو علاء active', 'clothing', 'sportswear', 'المحور المركزي', 'سيتي مول', 'commercial', 'مدينة السادات', 'سيتي مول السادات، المحور المركزي، مدينة السادات', 30.3679, 30.5057, true, true, 96, 'Verified_Partner', ARRAY['اكتيف', 'أكتيف', 'active', 'ابو علاء', 'ملابس رياضية', 'كوتشيات', 'ترنجات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CLO_003', 'دالي دريس Daly Dress', 'Daly Dress Sadat', 'دالي دريس daly dress', 'clothing', 'fashion', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور التجاري، بجوار سيتي مول، مدينة السادات', 30.3685, 30.5062, true, true, 95, 'Verified_Partner', ARRAY['دالي دريس', 'daly dress', 'ملابس كاجوال', 'ازياء']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CLO_004', 'كارينا Carina السادات', 'Carina Wear City Mall', 'كارينا carina السادات', 'clothing', 'womenswear', 'المحور المركزي', 'سيتي مول', 'commercial', 'مدينة السادات', 'سيتي مول السادات، المحور المركزي، مدينة السادات', 30.3677, 30.5055, true, true, 94, 'Verified_Partner', ARRAY['كارينا', 'carina', 'ملابس حريمي', 'بادي كارينا', 'لانجري']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CLO_005', 'سنتر الحجاز للملابس', 'Al Hegaz Clothing Center', 'سنتر الحجاز للملابس', 'clothing', 'department_store', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة، أمام مول زهران، مدينة السادات', 30.3804, 30.5159, true, true, 95, 'Verified_Partner', ARRAY['الحجاز', 'سنتر الحجاز', 'ملابس اطفال', 'ملابس حريمي', 'اقمشة', 'طرح وعبايات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_CLO_006', 'أحذية باتا Bata', 'Bata Shoes Sadat', 'احذيه باتا bata', 'clothing', 'shoes', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الأولى، بجوار مسجد الهدى، مدينة السادات', 30.3662, 30.5028, true, true, 93, 'Verified_Partner', ARRAY['باتا', 'احذية باتا', 'bata', 'جزم', 'كوتشيات', 'شوزات', 'احذية جلدية']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_ELE_001_A', 'فرع فودافون - المنطقة الأولى', 'Vodafone Egypt - Zone 1 Branch', 'فرع فودافون - المنطقه الاولي', 'electronics', 'telecom', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.3663, 30.503, true, true, 98, 'Verified_Partner', ARRAY['فودافون', 'فرع فودافون', 'vodafone', 'فودافون كاش', 'خطوط فودافون', 'نت فودافون', 'خدمة عملاء فودافون']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_ELE_001_B', 'فرع فودافون - سيتي مول', 'Vodafone Egypt - City Mall Branch', 'فرع فودافون - سيتي مول', 'electronics', 'telecom', 'المحور المركزي', 'سيتي مول', 'commercial', 'مدينة السادات', 'سيتي مول السادات، المحور المركزي، مدينة السادات', 30.3678, 30.5056, true, true, 97, 'Verified_Partner', ARRAY['فودافون سيتي مول', 'فودافون', 'vodafone', 'فودافون كاش']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_ELE_002_A', 'فرع وي WE - سنترال السادات', 'Telecom Egypt WE - Main Central', 'فرع وي we - سنترال السادات', 'electronics', 'telecom', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'مبنى السنترال الرئيسي، المنطقة الأولى، مدينة السادات', 30.3655, 30.502, true, true, 98, 'Verified_Partner', ARRAY['وي', 'we', 'المصرية للاتصالات', 'سنترال السادات', 'تليفون ارضي', 'نت منزلي', 'راوتر', 'خط وي']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_ELE_002_B', 'فرع وي WE - سيتي مول', 'Telecom Egypt WE - City Mall', 'فرع وي we - سيتي مول', 'electronics', 'telecom', 'المحور المركزي', 'سيتي مول', 'commercial', 'مدينة السادات', 'سيتي مول السادات، الدور الأرضي، مدينة السادات', 30.36785, 30.50565, true, true, 96, 'Verified_Partner', ARRAY['وي سيتي مول', 'we سيتي مول', 'وي', 'المصرية للاتصالات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_ELE_003', 'فرع أورنج Orange السادات', 'Orange Egypt - Sadat City', 'فرع اورنج orange السادات', 'electronics', 'telecom', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.36645, 30.5032, true, true, 96, 'Verified_Partner', ARRAY['اورنج', 'أورنج', 'orange', 'موبينيل', 'اورنج كاش', 'فرع اورنج', 'خطوط اورنج']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_ELE_004_A', 'فرع إي آند مصر e& - المحور المركزي', 'e& Egypt (Etisalat) - Central Axis', 'فرع اي اند مصر e& - المحور المركزي', 'electronics', 'telecom', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور المركزي التجاري، بجوار سيتي مول، مدينة السادات', 30.3684, 30.5061, true, true, 97, 'Verified_Partner', ARRAY['اتصالات', 'اي اند', 'e&', 'etisalat', 'اتصالات كاش', 'فرع اتصالات', 'شركة اتصالات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_ELE_004_B', 'فرع إي آند مصر e& - سوق 4', 'e& Egypt (Etisalat) - Zone 4 Market', 'فرع اي اند مصر e& - سوق 4', 'electronics', 'telecom', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة، أمام مول زهران، مدينة السادات', 30.3802, 30.5158, true, true, 95, 'Verified_Partner', ARRAY['اتصالات سوق 4', 'فرع اتصالات سوق 4', 'اتصالات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_ELE_005', 'بي تك B.Tech السادات', 'B.Tech Sadat City', 'بي تك b.tech السادات', 'electronics', 'home_appliances', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور المركزي التجاري، أمام مجمع البنوك، مدينة السادات', 30.369, 30.5072, true, true, 98, 'Verified_Partner', ARRAY['بي تك', 'btech', 'b.tech', 'تقسيط بي تك', 'ميني كاش', 'اجهزة كهربائية', 'ثلاجات', 'غسالات', 'شاشات', 'موبايلات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_ELE_006', 'العربي جروب El Araby Store', 'El Araby Group Store Sadat', 'العربي جروب el araby store', 'electronics', 'home_appliances', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور المركزي التجاري، مدينة السادات', 30.3698, 30.508, true, true, 97, 'Verified_Partner', ARRAY['العربي', 'توشيبا العربي', 'elaraby', 'تورنيدو', 'شارب', 'اجهزة كهربائية', 'شاشات', 'مراوح']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_ELE_007', 'رنين Raneen السادات', 'Raneen Sadat City', 'رنين raneen السادات', 'electronics', 'home_appliances', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور التجاري، مدينة السادات', 30.3702, 30.5085, true, true, 96, 'Verified_Partner', ARRAY['رنين', 'raneen', 'عروض رنين', 'اجهزة كهربائية', 'ادوات منزلية', 'مفروشات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_ELE_008', 'الشناوي موبايل السادات', 'El Shennawy Mobile Sadat', 'الشناوي موبايل السادات', 'electronics', 'mobile_phones', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.36625, 30.50295, true, true, 95, 'Verified_Partner', ARRAY['الشناوي', 'الشناوي موبايل', 'elshennawy', 'موبايلات', 'ايفون', 'سامسونج', 'اكسسوارات موبايل', 'صيانة موبايل']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_BTC_001', 'جزارة البرنس للحوم البلدية', 'El Prince Butcher', 'جزاره البرنس للحوم البلديه', 'butcher', 'butcher', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة، مدينة السادات', 30.38015, 30.51585, true, true, 96, 'Verified_Partner', ARRAY['جزارة البرنس', 'جزارة', 'لحوم بلدي', 'كندوز', 'ضاني', 'مفروم', 'جزار']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_BTC_002', 'جزارة الهدى', 'Al Hoda Fresh Meat', 'جزاره الهدي', 'butcher', 'butcher', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'المنطقة الأولى، بجوار مسجد الهدى والنور، مدينة السادات', 30.3668, 30.5034, true, true, 94, 'Verified_Partner', ARRAY['جزارة الهدى', 'جزار', 'لحمة', 'لحوم طازجة', 'ضاني']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_BTC_003', 'دواجن الوطنية والريفي', 'Al Watania Poultry', 'دواجن الوطنيه والريفي', 'butcher', 'poultry', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق الطيور، المنطقة الرابعة، مدينة السادات', 30.3807, 30.5167, true, true, 95, 'Verified_Partner', ARRAY['فراخ', 'دواجن', 'فراخ بيضاء', 'بانيه', 'بط', 'حمام', 'محل فراخ', 'دواجن الوطنية']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_BAK_001', 'مخابز وحلواني الأمانة', 'Al Amana Bakery', 'مخابز وحلواني الامانه', 'bakery', 'bakery', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.36615, 30.50275, true, true, 96, 'Verified_Partner', ARRAY['مخبز الامانة', 'مخابز الامانة', 'الامانة', 'فينو', 'عيش', 'مخبوزات', 'باتيه', 'كرواسون']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_BAK_002', 'مخبز وحلواني البركة', 'Al Baraka Modern Bakery', 'مخبز وحلواني البركه', 'bakery', 'bakery', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة، مدينة السادات', 30.38005, 30.51595, true, true, 95, 'Verified_Partner', ARRAY['مخبز البركة', 'البركة', 'فينو', 'عيش فينو', 'مخبوزات سوق 4']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_BAK_003', 'أفران العهد الجديد للعيش البلدي', 'Al Ahed El Gadeed Baladi Bread', 'افران العهد الجديد للعيش البلدي', 'bakery', 'baladi_bread', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'المنطقة الأولى، خلف المعهد الفندقي، مدينة السادات', 30.3657, 30.5022, true, true, 94, 'Verified_Partner', ARRAY['فرن عيش', 'عيش بلدي', 'فرن بلدي', 'مخبز بلدي', 'بطاقة التموين']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_BAK_004', 'مخابز الشرق الآلية', 'Al Sharq Automated Bakery', 'مخابز الشرق الاليه', 'bakery', 'bakery', 'المنطقة الثانية', NULL, 'commercial', 'مدينة السادات', 'المنطقة الثانية، بجوار سوبر ماركت الراية، مدينة السادات', 30.3694, 30.5111, true, true, 93, 'Verified_Partner', ARRAY['مخبز الشرق', 'الشرق', 'مخبوزات', 'عيش آلي', 'توست']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RET_001', 'مكتبة الأهرام الحديثة', 'Al Ahram Modern Bookshop', 'مكتبه الاهرام الحديثه', 'general_retail', 'stationery', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.36645, 30.50325, true, true, 95, 'Verified_Partner', ARRAY['مكتبة الاهرام', 'الاهرام', 'مكتبة', 'تصوير مستندات', 'طباعة', 'ادوات مدرسية', 'كتب وكشاكيل']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RET_002', 'سنتر البيت بيتك للأدوات المنزلية', 'El Beit Beitak Houseware', 'سنتر البيت بيتك للادوات المنزليه', 'general_retail', 'houseware', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة، أمام مول زهران، مدينة السادات', 30.38045, 30.51605, true, true, 94, 'Verified_Partner', ARRAY['البيت بيتك', 'ادوات منزلية', 'جهاز عرائس', 'حلل وصواني', 'زجاج وبلاستيكات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_RET_003', 'توي بوكس Toy Box للهدايا والألعاب', 'Toy Box City Mall', 'توي بوكس toy box للهدايا والالعاب', 'general_retail', 'toys_gifts', 'المحور المركزي', 'سيتي مول', 'commercial', 'مدينة السادات', 'سيتي مول السادات، الدور الأول، مدينة السادات', 30.36775, 30.50555, true, true, 93, 'Verified_Partner', ARRAY['توي بوكس', 'العاب اطفال', 'هدايا', 'toy box', 'سيتي مول']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_MNT_000', 'مركز صيانة الأجهزة والتكييف', 'Sadat Home Appliance & AC Repair Center', 'مركز صيانه الاجهزه والتكييف', 'maintenance', 'appliance_repair', 'المنطقة الحرفية', NULL, 'commercial', 'مدينة السادات', 'شارع الورش، المنطقة الحرفية، مدينة السادات', 30.362, 30.512, true, true, 96, 'Verified_Partner', ARRAY['صيانة', 'صيانة اجهزة', 'تصليح غسالات', 'تصليح ثلاجات', 'صيانة تكييف', 'مركز صيانة', 'تصليح', 'ورشة صيانة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_MNT_001', 'محلات أولاد علي للعدد والحدادة', 'Awlad Ali Hardware & Tools', 'محلات اولاد علي للعدد والحداده', 'maintenance', 'hardware_tools', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة، مدينة السادات', 30.3793, 30.5151, true, true, 94, 'Verified_Partner', ARRAY['اولاد علي', 'عدد وادوات', 'مسامير', 'حدادة', 'دريل وشنيور', 'محل عدد']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_MNT_002', 'سنتر المهندس للسباكة والأدوات الصحية', 'Al Mohandes Sanitary & Plumbing', 'سنتر المهندس للسباكه والادوات الصحيه', 'maintenance', 'plumbing', 'المنطقة الأولى', NULL, 'commercial', 'مدينة السادات', 'المنطقة الأولى، شارع المدارس، مدينة السادات', 30.367, 30.5039, true, true, 93, 'Verified_Partner', ARRAY['المهندس للسباكة', 'سباكة', 'ادوات صحية', 'حنفيات ومواسير', 'سيراميك وخلاطات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_MNT_003', 'شركة الأهرام للتوريدات الكهربائية', 'Al Ahram Electrical Supplies', 'شركه الاهرام للتوريدات الكهربائيه', 'maintenance', 'electrical_supplies', 'المنطقة الثانية', NULL, 'commercial', 'مدينة السادات', 'المنطقة الثانية، الشارع التجاري، مدينة السادات', 30.3688, 30.5102, true, true, 92, 'Verified_Partner', ARRAY['الاهرام للكهرباء', 'كهربائي', 'ليدات', 'اسلاك وكابلات', 'مفاتيح كهرباء']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_AUT_001', 'مركز غبور أوتو السادات', 'Ghabbour Auto Service Sadat', 'مركز غبور اوتو السادات', 'automotive', 'car_service', 'المنطقة الصناعية الأولى', NULL, 'commercial', 'مدينة السادات', 'المنطقة الصناعية الأولى، مدينة السادات', 30.355, 30.51, true, true, 96, 'Verified_Partner', ARRAY['غبور', 'غبور اوتو', 'ghabbour', 'صيانة سيارات', 'توكيل هيونداي', 'شيري', 'هافال']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_AUT_002', 'مركز المنصور للسيارات', 'Mansour Automotive Sadat', 'مركز المنصور للسيارات', 'automotive', 'car_dealership', 'المنطقة الصناعية الثالثة', NULL, 'commercial', 'مدينة السادات', 'المنطقة الصناعية الثالثة، مدينة السادات', 30.36, 30.49, true, true, 95, 'Verified_Partner', ARRAY['المنصور', 'المنصور للسيارات', 'شيفروليه', 'اوبل', 'mansour', 'توكيل سيارات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_AUT_003', 'مركز الأمل للإطارات وضبط الزوايا', 'Al Amal Tires & Alignment Bridgestone', 'مركز الامل للاطارات وضبط الزوايا', 'automotive', 'tires_alignment', 'المنطقة الرابعة', NULL, 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة، أمام مول زهران، مدينة السادات', 30.3795, 30.5152, true, true, 94, 'Verified_Partner', ARRAY['الامل للاطارات', 'ضبط زوايا', 'كاوتش', 'بريدجستون', 'ترصيص', 'نيتروجين']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_AUT_004', 'مغسلة سيارات VIP السادات', 'VIP Car Wash & Detailing Sadat', 'مغسله سيارات vip السادات', 'automotive', 'car_wash', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور المركزي، بجوار محطة توتال، مدينة السادات', 30.3693, 30.5079, true, true, 93, 'Verified_Partner', ARRAY['مغسلة سيارات', 'كار واش', 'غسيل كيماوي', 'تلميع سيارات', 'دراي كلين']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_GAS_001', 'محطة وطنية مدخل السادات', 'Wataniya Gas Station Desert Road Sadat', 'محطه وطنيه مدخل السادات', 'gas_station', 'gas_station', 'مدخل السادات الصحراوي', NULL, 'amenity', 'مدينة السادات', 'طريق القاهرة الإسكندرية الصحراوي، مدخل مدينة السادات الرئيسي', 30.3451, 30.5282, true, true, 98, 'Verified_Partner', ARRAY['وطنية', 'محطة وطنية', 'بنزينة وطنية', 'بنزين 92', 'بنزين 95', 'سولار', 'استراحة وطنية']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_GAS_002', 'محطة شيل أوت مدخل السادات', 'ChillOut Gas Station Sadat Entrance', 'محطه شيل اوت مدخل السادات', 'gas_station', 'gas_station', 'مدخل السادات الصحراوي', NULL, 'amenity', 'مدينة السادات', 'طريق القاهرة الإسكندرية الصحراوي، مدخل مدينة السادات', 30.3477, 30.52615, true, true, 98, 'Verified_Partner', ARRAY['شيل اوت', 'chillout', 'بنزينة شيل اوت', 'محطة شيل اوت', 'شيل أوت']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_GAS_003', 'محطة توتال المحور المركزي', 'TotalEnergies Central Axis Sadat', 'محطه توتال المحور المركزي', 'gas_station', 'gas_station', 'المحور المركزي', NULL, 'amenity', 'مدينة السادات', 'المحور المركزي، بالقرب من جهاز المدينة، مدينة السادات', 30.36915, 30.50765, true, true, 97, 'Verified_Partner', ARRAY['توتال', 'بنزينة توتال', 'total', 'محطة بنزين المحور', 'توتال انرجيز']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_GAS_004', 'محطة مصر للبترول - المنطقة الصناعية', 'Misr Petroleum Industrial Zone Sadat', 'محطه مصر للبترول - المنطقه الصناعيه', 'gas_station', 'gas_station', 'المنطقة الصناعية الأولى', NULL, 'amenity', 'مدينة السادات', 'مدخل المنطقة الصناعية الأولى، طريق السادات الرئيسي', 30.358, 30.512, true, true, 95, 'Verified_Partner', ARRAY['مصر للبترول', 'بنزينة مصر للبترول', 'سولار للمصانع', 'بنزينة المنطقة الصناعية']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_GAS_005', 'محطة غاز تك للغاز الطبيعي', 'Gastec Natural Gas Station Sadat', 'محطه غاز تك للغاز الطبيعي', 'gas_station', 'cng_station', 'طريق الخدمات الصحراوي', NULL, 'amenity', 'مدينة السادات', 'طريق الخدمات، مدخل مدينة السادات', 30.35, 30.523, true, true, 96, 'Verified_Partner', ARRAY['غاز تك', 'gastec', 'غاز طبيعي للسيارات', 'محطة غاز', 'تموين غاز']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_MED_001', 'مستشفى السادات المركزي العام', 'Sadat General Central Hospital', 'مستشفي السادات المركزي العام', 'medical', 'general_hospital', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'المنطقة السكنية الأولى، مدينة السادات، المنوفية', 30.3674, 30.5043, true, true, 99, 'Verified_Partner', ARRAY['مستشفى السادات', 'المستشفى العام', 'مستشفى السادات العام', 'طوارئ مستشفى السادات', 'مستشفي']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_MED_002', 'مستشفى دار الشفاء التخصصي', 'Dar Al Shifa Specialized Hospital Sadat', 'مستشفي دار الشفاء التخصصي', 'medical', 'specialized_hospital', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.3668, 30.5036, true, true, 97, 'Verified_Partner', ARRAY['دار الشفاء', 'مستشفى دار الشفاء', 'مستشفي دار الشفا', 'طوارئ خاصة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_MED_003', 'مستشفى الهلال الأحمر التخصصي', 'Red Crescent Hospital Sadat', 'مستشفي الهلال الاحمر التخصصي', 'medical', 'hospital', 'المنطقة الرابعة', NULL, 'amenity', 'مدينة السادات', 'المنطقة الرابعة، بجوار مجمع المدارس، مدينة السادات', 30.3789, 30.5168, true, true, 96, 'Verified_Partner', ARRAY['الهلال الاحمر', 'مستشفى الهلال الاحمر', 'الهلال الاحمر السادات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_MED_004', 'معمل البرج للتحاليل الطبية', 'Al Borg Medical Laboratories Sadat', 'معمل البرج للتحاليل الطبيه', 'medical', 'laboratory', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.36635, 30.5031, true, true, 97, 'Verified_Partner', ARRAY['معمل البرج', 'البرج', 'تحاليل طبية', 'معمل تحاليل', 'al borg']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_MED_005', 'معمل المختبر للتحاليل الطبية', 'Al Mokhtabar Laboratory Sadat', 'معمل المختبر للتحاليل الطبيه', 'medical', 'laboratory', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'شارع جمال عبد الناصر، أمام مستشفى السادات المركزي، مدينة السادات', 30.3665, 30.5033, true, true, 97, 'Verified_Partner', ARRAY['المختبر', 'معمل المختبر', 'تحاليل المختبر', 'معمل تحاليل']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_MED_006', 'معمل ألفا سكان للتحاليل والأشعة', 'Alfa Scan & Lab City Mall Sadat', 'معمل الفا سكان للتحاليل والاشعه', 'medical', 'radiology_lab', 'المحور المركزي', 'سيتي مول', 'amenity', 'مدينة السادات', 'سيتي مول السادات، الدور الثاني الطبي، مدينة السادات', 30.3678, 30.5056, true, true, 96, 'Verified_Partner', ARRAY['الفا سكان', 'ألفا سكان', 'alfa scan', 'مركز اشعة', 'اشعة مقطعية', 'رنين مغناطيسي', 'سونار']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_EDU_001', 'جامعة مدينة السادات - رئاسة الجامعة', 'University of Sadat City - Headquarters', 'جامعه مدينه السادات - رئاسه الجامعه', 'education', 'university_hq', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.3658, 30.5018, true, true, 99, 'Verified_Partner', ARRAY['جامعة السادات', 'جامعة مدينة السادات', 'ادارة الجامعة', 'رئاسة جامعة السادات', 'جامعه السادات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_EDU_002', 'كلية الطب البيطري جامعة السادات', 'Faculty of Veterinary Medicine - USC', 'كليه الطب البيطري جامعه السادات', 'education', 'college', 'المنطقة السابعة', NULL, 'amenity', 'مدينة السادات', 'المنطقة السابعة، مجمع كليات جامعة السادات، مدينة السادات', 30.376, 30.525, true, true, 98, 'Verified_Partner', ARRAY['طب بيطري', 'بيطري السادات', 'كلية الطب البيطري', 'جامعة السادات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_EDU_003', 'كلية الصيدلة جامعة السادات', 'Faculty of Pharmacy - USC', 'كليه الصيدله جامعه السادات', 'education', 'college', 'الحرم الجامعي الجديد', NULL, 'amenity', 'مدينة السادات', 'الحرم الجامعي الجديد، طريق الجامعة، مدينة السادات', 30.385, 30.53, true, true, 98, 'Verified_Partner', ARRAY['صيدلة السادات', 'كلية الصيدلة', 'صيدلة جامعة السادات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_EDU_004', 'كليات التجارة والحقوق جامعة السادات', 'Faculties of Commerce & Law - USC', 'كليات التجاره والحقوق جامعه السادات', 'education', 'college', 'المنطقة الثالثة', NULL, 'amenity', 'مدينة السادات', 'المنطقة الثالثة، الحرم الجامعي، مدينة السادات', 30.373, 30.513, true, true, 97, 'Verified_Partner', ARRAY['تجارة السادات', 'حقوق السادات', 'كلية التجارة', 'كلية الحقوق']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_EDU_005', 'معهد الهندسة الوراثية والتكنولوجيا الحيوية', 'Genetic Engineering & Biotechnology Institute (GEBRI)', 'معهد الهندسه الوراثيه والتكنولوجيا الحيويه', 'education', 'institute', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'المنطقة الأولى، الحرم الجامعي، مدينة السادات', 30.365, 30.501, true, true, 96, 'Verified_Partner', ARRAY['الهندسة الوراثية', 'معهد الهندسة الوراثية', 'gebri']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_EDU_006', 'مدرسة السلام الرسمية للغات', 'Al Salam Official Language School', 'مدرسه السلام الرسميه للغات', 'education', 'school', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'شارع المدارس، المنطقة الأولى، مدينة السادات', 30.3675, 30.5045, true, true, 95, 'Verified_Partner', ARRAY['مدرسة السلام', 'السلام لغات', 'مدرسة لغات', 'تجريبي لغات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_MAL_001', 'سيتي مول السادات', 'City Mall Sadat City', 'سيتي مول السادات', 'mall', 'shopping_mall', 'المحور المركزي', 'سيتي مول', 'commercial', 'مدينة السادات', 'المحور المركزي، بالقرب من جهاز تنمية المدينة، مدينة السادات', 30.3678, 30.5056, true, true, 100, 'Verified_Partner', ARRAY['سيتي مول', 'city mall', 'المول', 'مول السادات', 'سيتي مول السادات', 'مول تجاري', 'فود كورت']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_MAL_002', 'مول زهران التجاري', 'Zahran Mall Sadat', 'مول زهران التجاري', 'mall', 'shopping_mall', 'المنطقة الرابعة', 'مول زهران', 'commercial', 'مدينة السادات', 'سوق المنطقة الرابعة، مدينة السادات', 30.3804, 30.5158, true, true, 98, 'Verified_Partner', ARRAY['مول زهران', 'زهران مول', 'مول 4', 'مول المنطقة الرابعة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_MAL_003', 'سيتي سنتر السادات التجاري', 'City Center Sadat', 'سيتي سنتر السادات التجاري', 'mall', 'commercial_center', 'المنطقة الأولى', 'سيتي سنتر السادات', 'commercial', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.3663, 30.503, true, true, 96, 'Verified_Partner', ARRAY['سيتي سنتر', 'مول سيتي سنتر', 'سيتي سنتر السادات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_MAL_004', 'مول ريحانة سنتر', 'Rihana Center Mall', 'مول ريحانه سنتر', 'mall', 'shopping_mall', 'المنطقة الخامسة', 'مول ريحانة سنتر', 'commercial', 'مدينة السادات', 'ميدان المنطقة الخامسة، مدينة السادات', 30.3768, 30.5146, true, true, 94, 'Verified_Partner', ARRAY['مول ريحانة', 'ريحانة سنتر', 'مول المنطقة الخامسة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_FIN_001_A', 'البنك الأهلي المصري - فرع المنطقة الأولى', 'National Bank of Egypt - Zone 1 Branch', 'البنك الاهلي المصري - فرع المنطقه الاولي', 'finance', 'bank', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.3662, 30.5028, true, true, 99, 'Verified_Partner', ARRAY['البنك الاهلي', 'البنك الأهلي', 'nbe', 'الاهلي', 'فرع البنك الاهلي', 'atm الاهلي', 'بنك']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_FIN_001_B', 'البنك الأهلي المصري - فرع المنطقة الصناعية', 'National Bank of Egypt - Industrial Zone Branch', 'البنك الاهلي المصري - فرع المنطقه الصناعيه', 'finance', 'bank', 'المنطقة الصناعية الأولى', NULL, 'amenity', 'مدينة السادات', 'المنطقة الصناعية الأولى، أمام مجمع الخدمات الصناعي، مدينة السادات', 30.3565, 30.5115, true, true, 98, 'Verified_Partner', ARRAY['البنك الاهلي المنطقة الصناعية', 'اهلي صناعية', 'البنك الاهلي المصري']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_FIN_002_A', 'بنك مصر - فرع المنطقة الأولى', 'Banque Misr - Zone 1 Branch', 'بنك مصر - فرع المنطقه الاولي', 'finance', 'bank', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'شارع جمال عبد الناصر، بجوار مجمع المصالح، المنطقة الأولى، مدينة السادات', 30.3667, 30.5036, true, true, 99, 'Verified_Partner', ARRAY['بنك مصر', 'banque misr', 'فرع بنك مصر', 'atm بنك مصر', 'بنك']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_FIN_002_B', 'بنك مصر - فرع سوق 4', 'Banque Misr - Zone 4 Market Branch', 'بنك مصر - فرع سوق 4', 'finance', 'bank', 'المنطقة الرابعة', NULL, 'amenity', 'مدينة السادات', 'سوق المنطقة الرابعة، أمام مول زهران، مدينة السادات', 30.3803, 30.5157, true, true, 97, 'Verified_Partner', ARRAY['بنك مصر سوق 4', 'فرع بنك مصر سوق 4', 'بنك مصر']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_FIN_003', 'البنك التجاري الدولي CIB', 'Commercial International Bank CIB Sadat', 'البنك التجاري الدولي cib', 'finance', 'bank', 'المحور المركزي', NULL, 'amenity', 'مدينة السادات', 'مجمع البنوك، المحور المركزي، مدينة السادات', 30.3694, 30.5074, true, true, 98, 'Verified_Partner', ARRAY['cib', 'بنك cib', 'البنك التجاري الدولي', 'سي اي بي', 'فرع cib', 'atm cib']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_FIN_004', 'بنك QNB الأهلي', 'QNB Alahli Bank Sadat', 'بنك qnb الاهلي', 'finance', 'bank', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.3665, 30.5033, true, true, 97, 'Verified_Partner', ARRAY['qnb', 'بنك qnb', 'قطر الوطني', 'كيو ان بي', 'بنك']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_FIN_005', 'بنك القاهرة السادات', 'Banque du Caire Sadat', 'بنك القاهره السادات', 'finance', 'bank', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'المنطقة السكنية الأولى، بجوار مجلس المدينة، مدينة السادات', 30.3659, 30.5021, true, true, 96, 'Verified_Partner', ARRAY['بنك القاهرة', 'القاهرة', 'banque du caire', 'فرع بنك القاهرة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_FIN_006', 'بنك التعمير والإسكان', 'Housing & Development Bank Sadat', 'بنك التعمير والاسكان', 'finance', 'bank', 'المنطقة الثانية', NULL, 'amenity', 'مدينة السادات', 'المنطقة الثانية، بجوار مستشفى اليوم الواحد، مدينة السادات', 30.3696, 30.5113, true, true, 96, 'Verified_Partner', ARRAY['بنك الاسكان والتعمير', 'بنك الاسكان', 'التعمير والاسكان', 'شقق الاسكان', 'حجز اراضي']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SHP_001_A', 'مكتب بريد السادات الرئيسي', 'Sadat Main Post Office', 'مكتب بريد السادات الرئيسي', 'shipping', 'post_office', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'شارع جمال عبد الناصر، أمام مجلس المدينة، المنطقة الأولى، مدينة السادات', 30.3656, 30.5021, true, true, 98, 'Verified_Partner', ARRAY['البريد', 'بريد السادات', 'مكتب البريد', 'البوسطة', 'حساب توفير', 'قبض المعاش', 'طرود البريد']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SHP_001_B', 'مكتب بريد المنطقة الرابعة', 'Zone 4 Post Office Sadat', 'مكتب بريد المنطقه الرابعه', 'shipping', 'post_office', 'المنطقة الرابعة', NULL, 'amenity', 'مدينة السادات', 'سوق المنطقة الرابعة، مدينة السادات', 30.3796, 30.5154, true, true, 96, 'Verified_Partner', ARRAY['بريد سوق 4', 'بريد المنطقة الرابعة', 'بوسطة سوق 4']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SHP_002', 'فرع أرامكس Aramex للشحن', 'Aramex Express Sadat City', 'فرع ارامكس aramex للشحن', 'shipping', 'courier', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور المركزي التجاري، مدينة السادات', 30.3686, 30.5064, true, true, 96, 'Verified_Partner', ARRAY['ارامكس', 'أرامكس', 'aramex', 'شحن طرود', 'شركة شحن', 'توصيل شحنات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_HTL_001', 'فندق أمون السادات', 'Amoun Hotel Sadat City', 'فندق امون السادات', 'hotel', 'hotel', 'المنطقة الأولى', NULL, 'tourism', 'مدينة السادات', 'المنطقة الأولى، بالقرب من جهاز المدينة، مدينة السادات', 30.3653, 30.5019, true, true, 97, 'Verified_Partner', ARRAY['فندق امون', 'فندق أمون', 'amoun hotel', 'حجز غرف', 'اوتيل', 'فندق']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_HTL_002', 'فندق النزهة رويال', 'Al Nozha Royal Hotel Sadat', 'فندق النزهه رويال', 'hotel', 'resort_hotel', 'طريق الخدمات الصحراوي', NULL, 'tourism', 'مدينة السادات', 'طريق الخدمات، مدخل مدينة السادات، طريق مصر إسكندرية الصحراوي', 30.351, 30.522, true, true, 95, 'Verified_Partner', ARRAY['فندق النزهة', 'النزهة رويال', 'منتجع النزهة', 'فندق سياحي']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_EVT_001', 'قاعة اللؤلؤة الملكية للأفراح', 'Royal Pearl Wedding Hall', 'قاعه اللؤلؤه الملكيه للافراح', 'events', 'wedding_hall', 'طريق الحزام الأخضر', NULL, 'commercial', 'مدينة السادات', 'طريق الحزام الأخضر، مدخل مدينة السادات', 30.354, 30.518, true, true, 95, 'Verified_Partner', ARRAY['قاعة اللؤلؤة', 'قاعة افراح', 'حجز قاعة', 'افراح السادات', 'قاعات مناسبات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_EVT_002', 'قاعة جراند بالاس للمناسبات', 'Grand Palace Events & Conferences', 'قاعه جراند بالاس للمناسبات', 'events', 'banquet_hall', 'المحور المركزي', NULL, 'commercial', 'مدينة السادات', 'المحور المركزي، بالقرب من سيتي مول، مدينة السادات', 30.3689, 30.5069, true, true, 96, 'Verified_Partner', ARRAY['جراند بالاس', 'grand palace', 'قاعة مؤتمرات', 'حفلات', 'قاعة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SPT_001', 'جولدز جيم Gold''s Gym', 'Gold''s Gym Sadat City', 'جولدز جيم gold''s gym', 'sports', 'gym', 'المحور المركزي', NULL, 'leisure', 'مدينة السادات', 'المحور المركزي التجاري، أمام سيتي مول، مدينة السادات', 30.3685, 30.5063, true, true, 98, 'Verified_Partner', ARRAY['جولدز جيم', 'golds gym', 'جيم', 'لياقة بدنية', 'كمال اجسام', 'فتنس', 'جيم رجالي وحريمي']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SPT_002', 'نادي مدينة السادات الرياضي', 'Sadat City Sports Club', 'نادي مدينه السادات الرياضي', 'sports', 'sports_club', 'المنطقة الأولى', NULL, 'leisure', 'مدينة السادات', 'المنطقة السكنية الأولى، مدينة السادات', 30.368, 30.505, true, true, 97, 'Verified_Partner', ARRAY['نادي السادات', 'النادي الرياضي', 'ملاعب السادات', 'حمام سباحة نادي السادات', 'تنس وكورة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_SPT_003', 'نادي النجوم الرياضي', 'Al Nogoom Sports Club Sadat', 'نادي النجوم الرياضي', 'sports', 'sports_club', 'المنطقة الرابعة', NULL, 'leisure', 'مدينة السادات', 'المنطقة الرابعة، بجوار مجمع الخدمات، مدينة السادات', 30.3791, 30.5165, true, true, 95, 'Verified_Partner', ARRAY['نادي النجوم', 'ملعب النجوم', 'ملاعب نجيل صناعي', 'اكاديمية كورة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_COR_001', 'جمعية مستثمري مدينة السادات', 'Sadat City Investors Association (SCIA)', 'جمعيه مستثمري مدينه السادات', 'corporate', 'business_association', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'المنطقة الأولى، مبنى مجمع المصالح، مدينة السادات', 30.366, 30.5023, true, true, 97, 'Verified_Partner', ARRAY['جمعية المستثمرين', 'مستثمري السادات', 'خدمات رجال الاعمال', 'استثمار']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_COR_002', 'الغرفة التجارية بالسادات', 'Chamber of Commerce Sadat Branch', 'الغرفه التجاريه بالسادات', 'corporate', 'business_services', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.3659, 30.5022, true, true, 95, 'Verified_Partner', ARRAY['الغرفة التجارية', 'سجل تجاري', 'شهادة مزاولة المهنة', 'خدمات التجار']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_FAC_001', 'مصانع حديد عز السادات', 'Ezz Steel Factory Sadat City', 'مصانع حديد عز السادات', 'factory', 'heavy_industry', 'المنطقة الصناعية الثالثة', NULL, 'industrial', 'مدينة السادات', 'المنطقة الصناعية الثالثة، مجمع مصانع الصلب، مدينة السادات', 30.362, 30.485, true, true, 99, 'Verified_Partner', ARRAY['حديد عز', 'عز للصلب', 'ezz steel', 'مصنع عز', 'مصنع حديد']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_FAC_002', 'مصنع السويدي للكابلات Elsewedy', 'Elsewedy Electric Cables Sadat', 'مصنع السويدي للكابلات elsewedy', 'factory', 'cables_industry', 'المنطقة الصناعية الثانية', NULL, 'industrial', 'مدينة السادات', 'المنطقة الصناعية الثانية، مدينة السادات', 30.3585, 30.495, true, true, 98, 'Verified_Partner', ARRAY['السويدي', 'السويدي للكابلات', 'elsewedy electric', 'كابلات السويدي', 'مصنع السويدي']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_FAC_003', 'مصنع سيراميكا رويال السادات', 'Ceramica Royal Factory Sadat', 'مصنع سيراميكا رويال السادات', 'factory', 'ceramics_industry', 'المنطقة الصناعية الثانية', NULL, 'industrial', 'مدينة السادات', 'المنطقة الصناعية الثانية، مدينة السادات', 30.37, 30.478, true, true, 97, 'Verified_Partner', ARRAY['سيراميكا رويال', 'رويال للسيراميك', 'ceramica royal', 'مصنع رويال']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_FAC_004', 'مصنع جهينة للصناعات الغذائية', 'Juhayna Food Industries Sadat', 'مصنع جهينه للصناعات الغذائيه', 'factory', 'food_industry', 'المنطقة الصناعية الأولى', NULL, 'industrial', 'مدينة السادات', 'المنطقة الصناعية الأولى، مدينة السادات', 30.354, 30.508, true, true, 98, 'Verified_Partner', ARRAY['جهينة', 'مصنع جهينة', 'juhayna', 'البان جهينة', 'عصائر جهينة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_FAC_005', 'مصنع فاركو للأدوية', 'Pharco Pharmaceuticals Sadat', 'مصنع فاركو للادويه', 'factory', 'pharma_industry', 'المنطقة الصناعية الثالثة', NULL, 'industrial', 'مدينة السادات', 'المنطقة الصناعية الثالثة، مدينة السادات', 30.364, 30.488, true, true, 98, 'Verified_Partner', ARRAY['فاركو', 'مصنع فاركو', 'pharco', 'ادوية فاركو', 'مصنع ادوية']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_FAC_006', 'مصنع إيفا فارما للأدوية', 'Eva Pharma Factory Sadat City', 'مصنع ايفا فارما للادويه', 'factory', 'pharma_industry', 'المنطقة الصناعية الرابعة', NULL, 'industrial', 'مدينة السادات', 'المنطقة الصناعية الرابعة، مدينة السادات', 30.372, 30.476, true, true, 97, 'Verified_Partner', ARRAY['ايفا فارما', 'إيفا فارما', 'eva pharma', 'مصنع ايفا', 'ادوية']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_REL_001', 'مسجد الهدى والنور الكبير', 'Al Hoda & Al Nour Grand Mosque', 'مسجد الهدي والنور الكبير', 'religious', 'mosque', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'ميدان الهدى، المنطقة الأولى، مدينة السادات', 30.3669, 30.5035, true, true, 99, 'Verified_Partner', ARRAY['مسجد الهدى والنور', 'الهدى والنور', 'جامع الهدى', 'مسجد كبير', 'صلاة الجمعة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_REL_002', 'مسجد الشهداء الكبير', 'Al Shohadaa Grand Mosque', 'مسجد الشهداء الكبير', 'religious', 'mosque', 'المنطقة الرابعة', NULL, 'amenity', 'مدينة السادات', 'سوق المنطقة الرابعة، أمام مول زهران، مدينة السادات', 30.3805, 30.5162, true, true, 98, 'Verified_Partner', ARRAY['مسجد الشهداء', 'جامع الشهداء', 'مسجد سوق 4', 'صلاة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_REL_003', 'كنيسة العذراء ومارجرجس بالسادات', 'St. Mary & St. George Coptic Orthodox Church', 'كنيسه العذراء ومارجرجس بالسادات', 'religious', 'church', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'المنطقة السكنية الأولى، مدينة السادات', 30.3645, 30.5015, true, true, 98, 'Verified_Partner', ARRAY['كنيسة السادات', 'كنيسة العذراء', 'كنيسة مارجرجس', 'مطرانية السادات', 'قداس']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_GOV_001', 'جهاز تنمية مدينة السادات', 'Sadat City Development Authority', 'جهاز تنميه مدينه السادات', 'government', 'city_hall', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'المبنى الرئيسي لجهاز المدينة، المنطقة الأولى، مدينة السادات', 30.3654, 30.5023, true, true, 100, 'Verified_Partner', ARRAY['جهاز المدينة', 'جهاز تنمية السادات', 'رئاسة الجهاز', 'مجلس المدينة', 'تراخيص البناء', 'تخصيص اراضي']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_GOV_002', 'قسم شرطة مدينة السادات', 'Sadat City Police Station & Prosecution', 'قسم شرطه مدينه السادات', 'government', 'police', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'شارع جمال عبد الناصر، المنطقة الأولى، مدينة السادات', 30.365, 30.5027, true, true, 99, 'Verified_Partner', ARRAY['قسم الشرطة', 'قسم السادات', 'مركز شرطة السادات', 'النيابة', 'محكمة السادات', 'شرطة']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_GOV_003', 'وحدة مرور مدينة السادات', 'Sadat City Traffic Unit', 'وحده مرور مدينه السادات', 'government', 'traffic_unit', 'المنطقة الصناعية الأولى', NULL, 'amenity', 'مدينة السادات', 'المنطقة الصناعية الأولى، طريق السادات الرئيسي', 30.3555, 30.5105, true, true, 99, 'Verified_Partner', ARRAY['المرور', 'مرور السادات', 'تراخيص سيارات', 'رخصة قيادة', 'فحص السيارات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_GOV_004', 'مكتب جوازات السادات', 'Sadat Passports & Immigration Office', 'مكتب جوازات السادات', 'government', 'passport_office', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'مجمع قسم شرطة السادات، المنطقة الأولى، مدينة السادات', 30.3651, 30.5028, true, true, 98, 'Verified_Partner', ARRAY['جوازات السادات', 'مكتب الجوازات', 'استخراج جواز سفر', 'الجوازات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_GOV_005', 'مجمع المصالح الحكومية والتأمينات', 'Government Services & Social Insurance Complex', 'مجمع المصالح الحكوميه والتامينات', 'government', 'government_complex', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'المنطقة الأولى، أمام مجلس المدينة، مدينة السادات', 30.3658, 30.5024, true, true, 98, 'Verified_Partner', ARRAY['مجمع المصالح', 'التامينات', 'التأمينات والمعاشات', 'الشهر العقاري', 'الضرائب']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_TRN_001', 'مجمع مواقف السادات العمومي', 'Sadat Public Bus & Microbus Terminal', 'مجمع مواقف السادات العمومي', 'transport', 'bus_terminal', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'مدخل المنطقة الأولى، طريق الخدمات، مدينة السادات', 30.365, 30.5005, true, true, 100, 'Verified_Partner', ARRAY['الموقف', 'موقف السادات', 'مجمع المواقف', 'موقف الميكروباص', 'موقف القاهرة', 'موقف اسكندرية', 'موقف منوف', 'موقف شبين']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_TRN_002', 'محطة غرب الدلتا وجو باص السادات', 'West Delta & GoBus Station Sadat', 'محطه غرب الدلتا وجو باص السادات', 'transport', 'intercity_bus', 'المحور المركزي', NULL, 'amenity', 'مدينة السادات', 'المحور المركزي، بالقرب من سيتي مول، مدينة السادات', 30.366, 30.502, true, true, 98, 'Verified_Partner', ARRAY['غرب الدلتا', 'جو باص', 'اتوبيسات السادات', 'سوبرجيت', 'محطة الاتوبيس', 'مواصلات']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();

INSERT INTO public.sadat_places (
    id, name_ar, name_en, normalized_name, category, sub_category, district, mall_name, place_type, city, address, latitude, longitude, coordinates_verified, is_active, popularity_score, source, aliases
) VALUES (
    'SDT_SHP_TRN_003', 'موقف ميكروباص التحرير ورمسيس', 'Cairo Microbus Stand Sadat', 'موقف ميكروباص التحرير ورمسيس', 'transport', 'microbus_stand', 'المنطقة الأولى', NULL, 'amenity', 'مدينة السادات', 'بجوار مجمع المواقف، المنطقة الأولى، مدينة السادات', 30.3651, 30.5008, true, true, 99, 'Verified_Partner', ARRAY['موقف رمسيس', 'موقف التحرير', 'موقف المؤسسة', 'ميكروباص القاهرة', 'موقف مصر']
) ON CONFLICT (id) DO UPDATE SET
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    normalized_name = EXCLUDED.normalized_name,
    category = EXCLUDED.category,
    sub_category = EXCLUDED.sub_category,
    district = EXCLUDED.district,
    mall_name = EXCLUDED.mall_name,
    address = EXCLUDED.address,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    popularity_score = EXCLUDED.popularity_score,
    aliases = EXCLUDED.aliases,
    updated_at = NOW();
