CREATE TABLE testTable (
    -- Cannot SERIAL since we may add IDs in subscribers for test purposes, they then could conflict with auto incremented id from provider. 
    id int NOT NULL PRIMARY KEY
);