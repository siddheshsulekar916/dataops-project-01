import pandas as pd
import sys
import requests

def send_alert(message):
    # This is a placeholder for now
    print(f"📡 ALERT SENT: {message}")

def check_data_quality(file_path):
    print(f"🔍 Analyzing {file_path}...")
    
    try:
        df = pd.read_csv(file_path)
    except Exception as e:
        print(f"❌ FAILURE: Could not read file. {e}")
        sys.exit(1)

    # RULE 1: No missing IDs
    if df['log_id'].isnull().any():
        print("❌ FAILURE: Missing Log IDs detected!")
        sys.exit(1)

    # RULE 2: Correct Data Types
    try:
        pd.to_datetime(df['timestamp'])
    except:
        print("❌ FAILURE: Invalid timestamp format!")
        sys.exit(1)

    # RULE 3: Data Volume Check (MUST BE INSIDE THE FUNCTION)
    if len(df) < 3:
        send_alert("⚠️ WARNING: Data volume is lower than expected!")
        # We can choose to exit(1) here if we want to stop the pipeline 
        # for low volume, or just print a warning. Let's exit to be safe.
        sys.exit(1)

    print("✅ Quality Check Passed!")

if __name__ == "__main__":
    check_data_quality("sample_logs.csv")