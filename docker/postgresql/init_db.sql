-- Create the `dds_db` database
CREATE DATABASE dds_db;

-- Connect to `dds_db`
\connect dds_db;

-- Create the `permissions_user` table if it does not exist
CREATE TABLE IF NOT EXISTS permissions_user (
    id SERIAL PRIMARY KEY,
    admin BOOLEAN NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL
);

-- Insert the admin user if not already present
INSERT INTO permissions_user (admin, email)
VALUES (true, 'super@airbotix.in')
ON CONFLICT (email) DO NOTHING;
