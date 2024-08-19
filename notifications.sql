-- От тази таблица взимаме ID-то на потребителя
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL
);

-- В тази таблица пазим токъните на всички устройства които един потребител притежава
-- и кои точно нотификации за получаване да бъдат активни
CREATE TABLE tokens (
    user_id INT NOT NULL,
    token_id VARCHAR(50) NOT NULL,
    notification_code_101 BOOLEAN DEFAULT TRUE,
    notification_code_102 BOOLEAN DEFAULT TRUE,
    notification_code_103 BOOLEAN DEFAULT TRUE,
    notification_code_104 BOOLEAN DEFAULT TRUE,
    notification_code_105 BOOLEAN DEFAULT TRUE,

    CONSTRAINT fk_tokens_users
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- Тук постпвват всички нотификации съответно с ID-то на потребителя получател, както и самото 
-- съобщение и код за конкретната нотификация
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    receiver_id INT NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL
);

-- Тази таблица е свързано по ID с таблицата за нотификациите и пази информация
-- какъв статус код се е върнал при изпращането на завка към конкретно устройство
CREATE TABLE executions (
    id INT NOT NULL,
    token_id VARCHAR(50),
    timestamp TIMESTAMP,
    status_code INT,

        CONSTRAINT fk_executions_notifications
        FOREIGN KEY (id)
        REFERENCES notifications(id)
);



-- Тази тригер функция обработва всеки нов запис от таблицата за нотификации и минава през
-- всички устройства които един потребител е добавил, проверява дали конкретният тип
-- нотификация е позволена за получаване за това устройство и съответно я придвижва в
-- таблицата 'executions' за изпълнение
CREATE OR REPLACE FUNCTION notification_executor()
RETURNS TRIGGER AS $$
DECLARE
    record RECORD;
    current_notification BOOLEAN;
    query TEXT;
BEGIN
    FOR record IN (SELECT * FROM tokens WHERE user_id = NEW.receiver_id) LOOP
        query := format('SELECT %I FROM tokens WHERE token_id = %L', NEW.notification_type, record.token_id);
        EXECUTE query INTO current_notification;

        IF current_notification THEN
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


-- Тази функция симулира изпращането на заявка към сървър на firebase, като връща статус кода
-- Като параметър приема ID-то на устройството към което ще отиде нотификацията и съобщението
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


-- Тази тригер функция обработва всеки нов запис от таблицата 'executions' като добавя
-- какъв статус код се връща при всяка една от заявките
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


-- Примерни данни
INSERT INTO users (name) VALUES ('Vasil');


INSERT INTO tokens (
    user_id, 
    token_id, 
    notification_code_101, 
    notification_code_102, 
    notification_code_103, 
    notification_code_104, 
    notification_code_105
)
VALUES 
    (1, 'token_1', TRUE, TRUE, TRUE, FALSE, FALSE),
    (1, 'token_2', FALSE, FALSE, TRUE, TRUE, TRUE);


INSERT INTO notifications (receiver_id, message, notification_type)
VALUES 
    (1, 'Your order has been received.', 'notification_code_101'),
    (1, 'Your order has been received.', 'notification_code_104'),
    (1, 'Your order has been received.', 'notification_code_103');
    