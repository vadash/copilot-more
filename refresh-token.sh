#!/bin/bash

# Client ID for the vscode copilot
client_id="01ab8ac9400c4e429b23"

# --- First curl with retry ---
retry_count_first=5
retry_interval_first=2 # seconds
first_curl_success=false

echo "Requesting device and user codes..."

for ((i=0; i<retry_count_first; i++)); do
  response=$(curl -s https://github.com/login/device/code -X POST -d "client_id=$client_id&scope=user:email")

  if echo "$response" | grep -q "device_code=" && echo "$response" | grep -q "user_code="; then
    device_code=$(echo "$response" | grep -oE 'device_code=[^&]+' | cut -d '=' -f 2)
    user_code=$(echo "$response" | grep -oE 'user_code=[^&]+' | cut -d '=' -f 2)
    verification_uri=$(echo "$response" | grep -oE 'verification_uri=[^&]+' | cut -d '=' -f 2 | sed 's/%3A/:/g' | sed 's/%2F/\//g') # Decode URL encoding
    interval=$(echo "$response" | grep -oE 'interval=[^&]+' | cut -d '=' -f 2)

    if [ -n "$device_code" ] && [ -n "$user_code" ]; then
      echo "Please open $verification_uri and enter the following code: $user_code"
      echo "Waiting for authorization..."
      first_curl_success=true
      break
    fi
  else
    echo "Failed to get device and user codes. Retry attempt $((i+1)) of $retry_count_first..."
    if [ -n "$response" ]; then
      echo "Response was: $response"
    else
      echo "No response received."
    fi
  fi
  sleep $retry_interval_first
done

if ! $first_curl_success; then
  echo "Failed to get device and user codes after $retry_count_first attempts. Exiting."
  exit 1
fi

# --- User authorization prompt ---
read -p "Press Enter once you have authorized the application..."

# --- Second curl with retry ---
retry_count_second=10
retry_interval_second=${interval:-5} # Use interval from first response or default to 5 seconds
second_curl_success=false
access_token=""

echo "Requesting access token..."

for ((i=0; i<retry_count_second; i++)); do
  response_access_token=$(curl -s https://github.com/login/oauth/access_token -X POST -d "client_id=$client_id&scope=user:email&device_code=$device_code&grant_type=urn:ietf:params:oauth:grant-type:device_code")

  if echo "$response_access_token" | grep -q "access_token="; then
    access_token=$(echo "$response_access_token" | grep -oE 'access_token=[^&]+' | cut -d '=' -f 2)
    if [ -n "$access_token" ]; then
      echo "Successfully obtained access token."
      second_curl_success=true
      break
    fi
  else
    echo "Failed to get access token. Retry attempt $((i+1)) of $retry_count_second..."
    if [ -n "$response_access_token" ]; then
      echo "Response was: $response_access_token"
    else
      echo "No response received."
    fi
  fi
  sleep $retry_interval_second
done

if ! $second_curl_success; then
  echo "Failed to get access token after $retry_count_second attempts. Exiting."
  exit 1
fi

# --- Print the access token and instructions ---
echo "Your access token is: $access_token"
echo "Run the app with the following command:"
echo "REFRESH_TOKEN=$access_token" > .env
echo "REFRESH_TOKEN=$access_token poetry run uvicorn copilot_more.server:app --port 15432"

echo "Script finished."

exit 0
