This PowerShell script is a network monitoring tool that tracks logon events, particularly for an administrator account, on RDP. It's designed to alert users in real time about network connections and logon details via Discord using a webhook. The script uses Windows Event Logs to detect logon events and extracts information like the IP address, city, region, country, and the time of the event.

How to Use
Set Up Webhook: Obtain a webhook URL from your Discord server.
Run the Script: Launch the script in PowerShell. The script will prompt you to enter the webhook URL.
Monitor Events: The script starts monitoring and reporting logon events to the specified Discord channel.

Note
Make sure to replace the placeholder for the API token and server IP in the script with your actual token and IP.
This script is intended for educational or professional use. Please ensure it's used in accordance with applicable laws and guidelines.
