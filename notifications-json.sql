CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL
);

CREATE TABLE tokens (
    user_id INT NOT NULL,
    token_id VARCHAR(50) NOT NULL,
    notification_types JSON, --> Тук е промяната от първоначалната версия

    CONSTRAINT fk_tokens_users
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    receiver_id INT NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL
);

CREATE TABLE executions (
    id INT NOT NULL,
    token_id VARCHAR(50),
    timestamp TIMESTAMP,
    status_code INT,

        CONSTRAINT fk_executions_notifications
        FOREIGN KEY (id)
        REFERENCES notifications(id)
);


CREATE OR REPLACE FUNCTION notification_executor()
RETURNS TRIGGER AS $$
DECLARE
    record RECORD;
BEGIN
    FOR record IN (SELECT * FROM tokens WHERE user_id = NEW.receiver_id) LOOP

        IF (record.notification_types ->> NEW.notification_type) = 'true' THEN
            INSERT INTO executions (id, token_id, timestamp)
            VALUES (NEW.id, record.token_id, NOW());
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER notification_to_executions
AFTER INSERT ON notifications
FOR EACH ROW
EXECUTE FUNCTION notification_executor();


CREATE OR REPLACE FUNCTION send_firebase_request(token_id VARCHAR(50), message TEXT)
RETURNS INT AS $$
DECLARE
    status_codes INT[] := ARRAY[200, 201, 400, 404, 500];
    random_index INT;

BEGIN
    random_index := FLOOR(random() * array_length(status_codes, 1)) + 1;
    RETURN status_codes[random_index];

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION update_status_code()
RETURNS TRIGGER AS $$
DECLARE
    message TEXT;
    
BEGIN
    SELECT 
        n.message
    INTO message
    FROM 
        notifications AS n
    JOIN executions AS e ON n.id = e.id
    WHERE e.id = NEW.id;
   
    UPDATE executions SET status_code = send_firebase_request(NEW.token_id, message);

    RAISE NOTICE 'Message from notifications: %', message;

    RAISE NOTICE 'The token is: %', NEW.token_id;
   
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER executions_status_code
AFTER INSERT ON executions
FOR EACH ROW
EXECUTE FUNCTION update_status_code();


INSERT INTO users (name) VALUES ('Vasil');

INSERT INTO tokens (user_id, token_id, notification_types)
VALUES 
    (1, 'token_1', '{"101": "true", "102": "true", "103": "true", "104": "false", "105": "false"}'),
    (1, 'token_2', '{"101": "false", "102": "false", "103": "true", "104": "true", "105": "true"}');


INSERT INTO notifications (receiver_id, message, notification_type)
VALUES 
    (1, 'Your order has been received.', '101'), -- Тоукън 1 има активирана нотификация 101
    (1, 'Your order has been received.', '104'), -- Тоукън 2 има активирана нотификация 104
    (1, 'Your order has been received.', '103'); -- И двата тоукъна имат активирана нотификация 103
    