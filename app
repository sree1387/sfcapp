import mss
import os
import time
import tkinter as tk
from tkinter import ttk
import threading
from datetime import datetime, timedelta
import mysql.connector

# Define the path where you want to save the screenshots locally
download_folder = '/home/admin-sfc/Downloads'  # Specify the correct path

# Initialize capturing state, capture interval, and start_time
capturing = False
capture_interval = 600  # Default capture interval (10 minutes)
start_time = None  # Initialize start_time

# Function to capture a screenshot
def capture_screenshot():
    timestamp = time.strftime("%Y%m%d%H%M%S")
    screenshot_filename = f"screenshot_{timestamp}.png"
    screenshot_path = os.path.join(download_folder, screenshot_filename)

    with mss.mss() as sct:
        sct.shot(output=screenshot_path)

    status_label.config(text=f"Screenshot saved locally to {screenshot_path}")

# Function to track elapsed time and update the label
def track_elapsed_time():
    global start_time
    while capturing:
        if not start_time:
            start_time = datetime.now()

        elapsed_time = datetime.now() - start_time
        elapsed_time_str = str(elapsed_time).split('.')[0]  # Format elapsed time
        elapsed_time_label.config(text=f"Elapsed Time: {elapsed_time_str}")
        app.update_idletasks()  # Update the GUI
        time.sleep(1)

# Function to start the screenshot capture process
def start_capture():
    global capturing, capture_interval, start_time
    if not capturing:
        capturing = True
        capture_interval = int(interval_entry.get())  # Get the interval from the entry field
        status_label.config(text="Capture started.")
        start_button.config(state=tk.DISABLED)
        stop_button.config(state=tk.NORMAL)
        capture_screenshot_thread = threading.Thread(target=capture_screenshot_periodically)
        capture_screenshot_thread.daemon = True
        capture_screenshot_thread.start()

        # Start tracking elapsed time
        elapsed_time_thread = threading.Thread(target=track_elapsed_time)
        elapsed_time_thread.daemon = True
        elapsed_time_thread.start()

# Function to stop the screenshot capture process
def stop_capture():
    global capturing, start_time
    if capturing:
        capturing = False
        start_time = None  # Reset start_time
        timer_label.config(text="")
        status_label.config(text="Capture stopped.")
        start_button.config(state=tk.NORMAL)
        stop_button.config(state=tk.DISABLED)

        # Upload date and elapsed time to MySQL
        elapsed_time_str = elapsed_time_label.cget("text").replace("Elapsed Time: ", "")
        current_date = datetime.now().strftime('%Y-%m-%d')
        upload_to_mysql(current_date, elapsed_time_str)

# Function to capture screenshots at intervals
def capture_screenshot_periodically():
    global capture_interval
    while capturing:
        capture_screenshot()
        time_remaining = capture_interval
        while capturing and time_remaining > 0:
            time_remaining -= 1
            timer_label.config(text=f"Next capture in {time_remaining} seconds")
            app.update_idletasks()  # Update the GUI
            time.sleep(1)

# Function to upload date and elapsed time to MySQL
def upload_to_mysql(date, elapsed_time_str):
    try:
        connection = mysql.connector.connect(
            host="localhost",
            user="sfc",
            password="sfcadmin",
            database="details"
        )
        cursor = connection.cursor()

        insert_query = "INSERT INTO capture_times (capture_date, capture_time) VALUES (%s, %s)"
        values = (date, elapsed_time_str)

        cursor.execute(insert_query, values)
        connection.commit()

        cursor.close()
        connection.close()

        print("Date and elapsed time uploaded to MySQL.")
    except Exception as e:
        print(f"Error uploading to MySQL: {str(e)}")

# Create the main application window
app = tk.Tk()
app.title("SFCMTA - Screenshot Capture with Timer")

# Create and configure the interval entry field
interval_label = ttk.Label(app, text="Capture Interval (seconds):")
interval_label.pack()
interval_entry = ttk.Entry(app)
interval_entry.insert(0, "600")  # Default interval is 10 minutes
interval_entry.pack()

# Create the Start and Stop buttons
start_button = ttk.Button(app, text="Start Capture", command=start_capture)
start_button.pack()
stop_button = ttk.Button(app, text="Stop Capture", command=stop_capture, state=tk.DISABLED)
stop_button.pack()

# Create a status label
status_label = ttk.Label(app, text="")
status_label.pack()

# Create a timer label
timer_label = ttk.Label(app, text="")
timer_label.pack()

# Create an elapsed time label
elapsed_time_label = ttk.Label(app, text="Elapsed Time: 00:00")
elapsed_time_label.pack()

# Create a current date label
current_date_label = ttk.Label(app, text=f"Date: {datetime.now().strftime('%Y-%m-%d')}")
current_date_label.pack()

app.mainloop()
