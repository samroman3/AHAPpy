import os
import tkinter as tk
from tkinter import filedialog
import subprocess

class MainWindow:
    def __init__(self, root):
        self.root = root
        self.root.title("WAV to AHAP Converter")
        self.root.geometry("400x300")

        self.label = tk.Label(root, text="Select a WAV file:")
        self.label.pack()

        self.button = tk.Button(root, text="Browse", command=self.browse_file)
        self.button.pack()

        self.status_label = tk.Label(root, text="")
        self.status_label.pack()

    def browse_file(self):
         # Reset status label immediately
        self.reset_status()
        
        # Schedule file dialog after resetting status label
        self.root.after(100, self.open_file_dialog)

    def open_file_dialog(self):
        file_path = filedialog.askopenfilename(filetypes=[("WAV files", "*.wav")])
        if file_path:
            self.convert_to_ahap(file_path)

    def convert_to_ahap(self, wav_file):
        try:
            self.display_conversion_status("Converting...")
            # Extract directory and filename from the WAV file path
            directory = os.path.dirname(wav_file)
            filename = os.path.splitext(os.path.basename(wav_file))[0]
            # Construct the output AHAP file path using the same filename in the same directory
            output_ahap_file = os.path.join(directory, f"{filename}.ahap")
            subprocess.run(["python", "generate_ahap.py", wav_file, output_ahap_file])
            self.display_conversion_status("Conversion completed!")
        except Exception as e:
            print("Error:", e)
            self.display_conversion_status("Error during conversion")

    def display_conversion_status(self, status):
        self.status_label.config(text=status)

    def reset_status(self):
        self.status_label.config(text="")

def main():
    root = tk.Tk()
    app = MainWindow(root)
    root.mainloop()

if __name__ == "__main__":
    main()
