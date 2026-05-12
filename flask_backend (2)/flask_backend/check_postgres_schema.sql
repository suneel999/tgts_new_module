-- PostgreSQL Queries to Check Events and RSVP Table Structure
-- Run these queries in your PostgreSQL database to see the actual structure

-- 1. Check if events table exists and its structure
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'events'
ORDER BY ordinal_position;

-- 2. Check if event_rsvps table exists and its structure
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'event_rsvps'
ORDER BY ordinal_position;

-- 3. Check foreign key relationships
SELECT
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    tc.constraint_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND (tc.table_name = 'events' OR tc.table_name = 'event_rsvps');

-- 4. Check unique constraints
SELECT
    tc.table_name,
    kcu.column_name,
    tc.constraint_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'UNIQUE'
    AND tc.table_name = 'event_rsvps';

-- 5. Sample query: Get event with its RSVP count from the actual table
SELECT 
    e.id,
    e.title_en,
    e.rsvp_count AS stored_count,
    COUNT(er.id) AS actual_count_from_table
FROM events e
LEFT JOIN event_rsvps er ON e.id = er.event_id
GROUP BY e.id, e.title_en, e.rsvp_count;

