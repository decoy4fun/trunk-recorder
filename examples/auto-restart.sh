#!/bin/bash

# Define whether to enable email alerts ("yes" or "no") and what email address alerts are sent to.
# If enabled, make sure to configure your system's email service (e.g., Postfix, Sendmail, or an SMTP relay service like Gmail) to handle outgoing emails.
enable_emails="no"
email_address=""

#lines 10 through 87 handle email alerts and attachments. If disabled, skip to line 87

# Get the directory of the current script
script_dir="$(cd "$(dirname "$0")" && pwd)"

# Path to the config.json file
config_file="$script_dir/config.json"

# Function to parse JSON and extract a value for a given key
get_json_value() {
    local key=$1
    jq -r ".$key // empty" "$config_file"
}

# Parse the config.json file
if [[ -f "$config_file" ]]; then
    log_file_enabled=$(get_json_value "logFile")
    log_dir=$(get_json_value "logDir")
else
    log_file_enabled="false"
fi

# Determine the log directory
if [[ "$log_file_enabled" == "true" ]]; then
    if [[ -n "$log_dir" ]]; then
        # Use the specified logDir location
        log_path="$log_dir"
    else
        # Use the default /logs directory within the script's directory
        log_path="$script_dir/logs"
    fi
else
    log_path=""
fi

# Infinite loop to keep the script running
while true; do
    # Run Trunk Recorder
    ./trunk-recorder

    # Capture the exit code of the Trunk Recorder program
    exit_code=$?

    # Log the crash information to the console
    echo "Trunk-Recorder crashed with exit code $exit_code. Respawning.." >&2

    # Check if emails are enabled
    if [[ "$enable_emails" == "yes" ]]; then
        # Check if logs are enabled
        if [[ "$log_file_enabled" == "true" && -n "$log_path" ]]; then
            # Find the most recent log file in the log directory
            recent_log=$(ls -t "$log_path" 2>/dev/null | head -n 1)
            recent_log_path="$log_path/$recent_log"

            # Check if the most recent log file exists
            if [[ -f "$recent_log_path" ]]; then
                # Convert the log file to a plain text file
                converted_log="${recent_log_path}.txt"
                cp "$recent_log_path" "$converted_log"

                # Get the last 5 lines of the log file
                last_lines=$(tail -n 5 "$recent_log_path")
                
                # Send an email with the text file attached and the last 5 lines in the body
                echo -e "Trunk-Recorder crashed and failed to restart.\n\nExit Code: $exit_code.\n\nLast 5 log entries:\n$last_lines" | \
                mail -s "Trunk-Recorder crashed and failed to restart!" -A "$converted_log" "$email_address"

                # Clean up the temporary text file
                rm -f "$converted_log"
            else
                # If no log file exists, send an email without an attachment
                echo -e "Trunk-Recorder crashed and failed to restart.\n\nExit Code: $exit_code.\n\nNo logs found!" | \
                mail -s "Trunk-Recorder crashed and failed to restart!" "$email_address"
            fi
        else
            # Logs are not enabled, send an email without an attachment
            echo -e "Trunk-Recorder crashed and failed to restart.\n\nExit Code: $exit_code.\n\nLogging is disabled." | \
            mail -s "Trunk-Recorder crashed and failed to restart!" "$email_address"
        fi
    else
        # Emails are disabled, just log to console and try to restart
        echo "Trunk-Recorder crashed with exit code $exit_code. Respawning without sending an email."
    fi

    # Wait for 300 seconds before restarting the program
    sleep 300
done
