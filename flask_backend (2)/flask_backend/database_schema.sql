-- PostgreSQL Schema for Events and RSVPs
-- This shows the actual database structure

-- Events table
CREATE TABLE IF NOT EXISTS events (
    id VARCHAR(50) PRIMARY KEY,
    title_en VARCHAR(200) NOT NULL,
    title_te VARCHAR(200) NOT NULL,
    description_en TEXT NOT NULL,
    description_te TEXT NOT NULL,
    event_date TIMESTAMP NOT NULL,
    event_time VARCHAR(10) NOT NULL,
    location_en VARCHAR(200) NOT NULL,
    location_te VARCHAR(200) NOT NULL,
    image_url VARCHAR(500),
    rsvp_count INTEGER DEFAULT 0,  -- Stores the count
    is_published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Event RSVPs table (stores individual phone numbers)
CREATE TABLE IF NOT EXISTS event_rsvps (
    id VARCHAR(50) PRIMARY KEY,
    event_id VARCHAR(50) NOT NULL,
    phone_number VARCHAR(15) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign key relationship to events table
    CONSTRAINT fk_event_rsvp_event 
        FOREIGN KEY (event_id) 
        REFERENCES events(id) 
        ON DELETE CASCADE,
    
    -- Unique constraint: one phone number can only RSVP once per event
    CONSTRAINT unique_event_phone 
        UNIQUE (event_id, phone_number)
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_event_rsvps_event_id ON event_rsvps(event_id);
CREATE INDEX IF NOT EXISTS idx_event_rsvps_phone ON event_rsvps(phone_number);

