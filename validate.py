import pandas as pd
import sys
import requests

def check_data_quality(file_path):
    print(f"🔍 Analyzing {file_path}...")
    df = pd.read_csv(file_path)

    # RULE 1: No missing IDs
    if df['log_id'].isnull().any():
        print("❌ FAILURE: Missing Log IDs detected!")
        sys.exit(1) # This exit code tells the CI/CD pipeline to STOP

    # RULE 2: Correct Data Types
    if not pd.api.types.is_datetime64_any_dtype(pd.to_datetime(df['timestamp'])):
        print("❌ FAILURE: Invalid timestamp format!")
        sys.exit(1)

    print("✅ Quality Check Passed!")

if __name__ == "__main__":
    check_data_quality("sample_logs.csv")


def send_alert(message):
    webhook_url = "YOUR_WEBHOOK_URL_HERE" # We can set this up later
    payload = {"text": message}
    # requests.post(webhook_url, json=payload) 
    print(f"📡 ALERT SENT: {message}")

# Inside your check_data_quality function:
if len(df) < 3: # Example: If we expected more data
    send_alert("⚠️ WARNING: Data volume is lower than expected!")