-- Send request using Python
CREATE OR REPLACE FUNCTION send_firebase_request(token_id VARCHAR(50), message TEXT)
RETURNS INTEGER AS $$
import requests
url = 'https://fcm.googleapis.com/fcm/send'
headers = {
    'Authorization': 'key=YOUR_SERVER_KEY',
    'Content-Type': 'application/json'
}
payload = {
    'to': token_id,
    'notification': {
        'title': 'Notification Title',
        'body': message
    }
}
response = requests.post(url, headers=headers, json=payload)
return response.status_code
$$ LANGUAGE plpythonu;


-- Send request using Bash Script
CREATE OR REPLACE FUNCTION send_firebase_request(token_id VARCHAR(50), message TEXT)
RETURNS INTEGER AS $$

url='https://fcm.googleapis.com/fcm/send'

headers="Authorization: key=YOUR_SERVER_KEY\nContent-Type: application/json"

payload="{\"to\":\"$token_id\",\"notification\":{\"title\":\"Notification Title\",\"body\":\"$message\"}}"

response=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "$headers" -d "$payload" "$url")

echo $response
$$ LANGUAGE plsh;