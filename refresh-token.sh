#!/bin/bash

# Client ID for the vscode copilot
client_id="01ab8ac9400c4e429b23"

# Retry configuration for initial request
max_retries_initial=20
retry_delay_initial=3

# Get the device code with retries
response=""
device_code=""
user_code=""
for ((i=1; i<=max_retries_initial; i++)); do
    response=$(curl -s https://github.com/login/device/code -X POST -d "client_id=$client_id&scope=user:email")
    if [ $? -eq 0 ] && [[ "$response" == *"device_code"* ]]; then
        device_code=$(echo "$response" | grep -oE 'device_code=[^&]+' | cut -d '=' -f 2)
        user_code=$(echo "$response" | grep -oE 'user_code=[^&]+' | cut -d '=' -f 2)
        break
    else
        echo "Initial request failed (attempt $i/$max_retries_initial). Retrying in $retry_delay_initial seconds..."
        sleep $retry_delay_initial
    fi
done

if [ -z "$device_code" ]; then
    echo "Failed to get device code after $max_retries_initial attempts. Exiting."
    exit 1
fi

# Show user instructions
echo "Please open https://github.com/login/device/ and enter the following code: $user_code"
echo "Waiting for authorization..."

# Retry configuration for access token
max_retries_access=20
retry_delay_access=3

# Get access token with retries
access_token=""
for ((i=1; i<=max_retries_access; i++)); do
    response_access_token=$(curl -s https://github.com/login/oauth/access_token -X POST -d "client_id=$client_id&scope=user:email&device_code=$device_code&grant_type=urn:ietf:params:oauth:grant-type:device_code")
    
    if [ $? -eq 0 ]; then
        if [[ "$response_access_token" == *"access_token"* ]]; then
            access_token=$(echo "$response_access_token" | grep -oE 'access_token=[^&]+' | cut -d '=' -f 2)
            break
        else
            echo "Authorization pending (attempt $i/$max_retries_access). Retrying in $retry_delay_access seconds..."
        fi
    else
        echo "Network error (attempt $i/$max_retries_access). Retrying in $retry_delay_access seconds..."
    fi
    sleep $retry_delay_access
done

if [ -z "$access_token" ]; then
    echo "Failed to get access token after $max_retries_access attempts. Exiting."
    exit 1
fi

# Success output
echo "Your access token is: $access_token"
echo "Run the app with the following command:"
echo "REFRESH_TOKEN=$access_token" > .env
echo "REFRESH_TOKEN=$access_token poetry run uvicorn copilot_more.server:app --port 15432"
