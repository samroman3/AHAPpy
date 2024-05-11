import tkinter as tk
from tkinter import filedialog, messagebox, Menu
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
import matplotlib.patches as patches
import numpy as np
import json
from pydub import AudioSegment
import librosa
import os

def convert_wav_to_ahap(wav_file, output_ahap):
    try:
        audio = AudioSegment.from_file(wav_file, format="wav")
        audio = audio.set_channels(1).set_frame_rate(44100)
        samples = np.array(audio.get_array_of_samples())
        audio_data = samples.astype(np.float32) / 32768.0
        sample_rate = audio.frame_rate

        ahap_data = generate_ahap(audio_data, sample_rate)
        with open(output_ahap, 'w') as f:
            json.dump(ahap_data, f, indent=4)
        
        return ahap_data
    except Exception as e:
        print(f"Error converting WAV to AHAP: {e}")
        raise

def generate_ahap(audio_data, sample_rate):
    onsets = librosa.onset.onset_detect(y=audio_data, sr=sample_rate, units='time')
    pattern = []
    for onset in onsets:
        event = {
            "Event": {
                "Time": onset,
                "EventType": "HapticTransient",
                "EventParameters": [
                    {"ParameterID": "HapticIntensity", "ParameterValue": np.random.uniform(0.5, 1.0)},
                    {"ParameterID": "HapticSharpness", "ParameterValue": np.random.uniform(0.5, 1.0)}
                ]
            }
        }
        pattern.append(event)
    return {"Pattern": pattern}

class AHAPApplication:
    def __init__(self, master):
        self.master = master
        self.master.title("WAV to AHAP Converter and Editor")
        self.master.geometry("900x600")

        menu = tk.Menu(master)
        master.config(menu=menu)

        file_menu = tk.Menu(menu, tearoff=0)
        menu.add_cascade(label="File", menu=file_menu)
        file_menu.add_command(label="Open WAV", command=self.open_wav)
        file_menu.add_command(label="Open AHAP", command=self.open_ahap)
        file_menu.add_command(label="Save AHAP", command=self.save_ahap)

        self.status = tk.StringVar()
        self.status_bar = tk.Label(master, textvariable=self.status, bd=1, relief=tk.SUNKEN, anchor=tk.W)
        self.status_bar.pack(side=tk.BOTTOM, fill=tk.X)

        self.figure, self.ax = plt.subplots()
        self.canvas = FigureCanvasTkAgg(self.figure, master=self.master)
        self.canvas_widget = self.canvas.get_tk_widget()
        self.canvas_widget.pack(fill=tk.BOTH, expand=True)

        self.initialize_plot()

        self.canvas.mpl_connect('button_press_event', self.on_press)
        self.canvas.mpl_connect('button_release_event', self.on_release)
        self.canvas.mpl_connect('motion_notify_event', self.on_motion)
        self.canvas.mpl_connect('button_press_event', self.on_right_click)

        self.start_x = None
        self.current_rect = None
        self.rects = []
        self.dragging = False
        self.selected_rect = None
        self.last_context_menu = None
        self.resize_active = False

    def initialize_plot(self):
        self.ax.set_xlim(0, 10)
        self.ax.set_ylim(0, 2)
        self.ax.set_title('Haptic Patterns')
        self.ax.set_xlabel('Time (seconds)')
        self.ax.set_ylabel('Event Type')
        self.ax.set_yticks([0.5, 1.5])
        self.ax.set_yticklabels(['Transient', 'Continuous'])
        self.figure.canvas.draw()

    def open_wav(self):
        file_path = filedialog.askopenfilename(filetypes=[("WAV files", "*.wav")])
        if file_path:
            try:
                self.status.set("Converting WAV to AHAP...")
                output_ahap = os.path.splitext(file_path)[0] + '.ahap'
                ahap_data = convert_wav_to_ahap(file_path, output_ahap)
                self.load_ahap_data(ahap_data)
                self.status.set("Conversion complete. AHAP loaded for editing.")
            except Exception as e:
                messagebox.showerror("Conversion Failed", str(e))
                self.status.set("Error during conversion.")

    def open_ahap(self):
        file_path = filedialog.askopenfilename(filetypes=[("AHAP files", "*.ahap")])
        if file_path:
            with open(file_path, 'r') as file:
                ahap_data = json.load(file)
                self.load_ahap_data(ahap_data)
                self.status.set("AHAP file loaded.")

    def save_ahap(self):
        file_path = filedialog.asksaveasfilename(defaultextension=".ahap", filetypes=[("AHAP files", "*.ahap")])
        if file_path:
            with open(file_path, 'w') as file:
                json.dump(self.get_ahap_data(), file, indent=4)
            self.status.set("AHAP file saved.")

    def load_ahap_data(self, ahap_data):
        self.ax.clear()
        self.initialize_plot()
        self.rects.clear()

        for event in ahap_data['Pattern']:
            t = event['Event']['Time']
            duration = event['Event'].get('EventDuration', 0.1)
            if event['Event']['EventType'] == 'HapticTransient':
                rect = plt.Rectangle((t, 0.1), duration, 0.8, color='purple', alpha=0.5, picker=5)
            else:
                rect = plt.Rectangle((t, 1.1), duration, 0.8, color='green', alpha=0.5, picker=5)
            self.ax.add_patch(rect)
            self.rects.append(rect)
        self.figure.canvas.draw()

    def get_ahap_data(self):
        ahap_data = {"Pattern": []}
        for rect in self.rects:
            x, y = rect.get_xy()
            width = rect.get_width()
            event_type = "HapticTransient" if y < 1 else "HapticContinuous"
            event = {
                "Event": {
                    "Time": x,
                    "EventType": event_type,
                    "EventParameters": [
                        {"ParameterID": "HapticIntensity", "ParameterValue": np.random.uniform(0.5, 1.0)},
                        {"ParameterID": "HapticSharpness", "ParameterValue": np.random.uniform(0.5, 1.0)}
                    ]
                }
            }
            if event_type == "HapticContinuous":
                event["Event"]["EventDuration"] = width
            ahap_data["Pattern"].append(event)
        return ahap_data

    def on_press(self, event):
        if event.button == 1:  # Left mouse button
            self.dragging = False
            self.start_x = event.xdata
            if event.xdata is None or event.ydata is None:
                return
            for rect in self.rects:
                if rect.contains_point([event.xdata, event.ydata]):
                    self.selected_rect = rect
                    self.dragging = True
                    self.start_x = event.xdata
                    self.resize_active = event.xdata > (rect.get_x() + rect.get_width() - 0.1)
                    return
            if 0 <= event.ydata < 1:
                self.current_rect = plt.Rectangle((self.start_x, 0.1), 0.1, 0.8, color='purple', alpha=0.5)
                self.ax.add_patch(self.current_rect)
            elif 1 <= event.ydata < 2:
                self.current_rect = plt.Rectangle((self.start_x, 1.1), 0.1, 0.8, color='green', alpha=0.5)
                self.ax.add_patch(self.current_rect)
            else:
                self.current_rect = None
            self.figure.canvas.draw()


    def on_motion(self, event):
        if event.xdata is None or event.ydata is None:
            return
        
        if self.dragging and self.selected_rect:
            # Determine if we are resizing or moving the rectangle
            if self.resize_active:
                # Resizing the rectangle's width
                new_width = max(event.xdata - self.selected_rect.get_x(), 0.1)  # Minimum width of 0.1 for visibility
                self.selected_rect.set_width(new_width)
            else:
                # Moving the rectangle along the x-axis
                dx = event.xdata - self.start_x
                new_x = self.selected_rect.get_x() + dx
                # Ensure the event does not go out of bounds (negative times)
                if new_x < 0:
                    new_x = 0
                self.selected_rect.set_x(new_x)
                self.start_x = event.xdata
            self.figure.canvas.draw()
        elif self.current_rect:
            # Creating a new rectangle: update its width as the mouse moves
            width = event.xdata - self.start_x
            if width > 0:
                self.current_rect.set_width(width)
            self.figure.canvas.draw()

    def on_release(self, event):
        if self.current_rect:
            # Finalize the dimensions of a newly created rectangle
            self.rects.append(self.current_rect)
            self.current_rect = None
            self.figure.canvas.draw()
            self.status.set("Added a new event. Drag to move, drag edges to resize.")
        elif self.dragging and self.selected_rect:
            # Update the layout once the drag operation is complete
            self.selected_rect = None
            self.dragging = False
            self.figure.canvas.draw()
            self.status.set("Event updated. Right-click an event to delete.")
        self.update_ahap_data()

    def on_right_click(self, event):
        if event.button == 3:  # Right mouse button
            # Identify if the click is on any rectangle
            hit = None
            for rect in self.rects:
                if rect.contains_point([event.xdata, event.ydata]):
                    hit = rect
                    break
            if hit:
                # Show a context menu to delete the rectangle
                self.show_context_menu(event, hit)

    def show_context_menu(self, event, rect):
        self.last_context_menu = Menu(self.master, tearoff=0)
        self.last_context_menu.add_command(label="Delete", command=lambda: self.delete_rect(rect))
        self.last_context_menu.tk_popup(event.x_root, event.y_root)

    def delete_rect(self, rect):
        # Remove the rectangle from the plot and the list
        if rect in self.rects:
            rect.remove()
            self.rects.remove(rect)
            self.figure.canvas.draw()
            self.update_ahap_data()
            self.status.set("Event deleted.")

    def update_ahap_data(self):
        # Reflect the current state of rectangles (events) into the AHAP data structure
        ahap_data = {"Pattern": []}
        for rect in self.rects:
            x, y = rect.get_xy()
            width = rect.get_width()
            event_type = "HapticTransient" if y < 1 else "HapticContinuous"
            event = {
                "Event": {
                    "Time": x,
                    "EventType": event_type,
                    "EventParameters": [
                        {"ParameterID": "HapticIntensity", "ParameterValue": np.random.uniform(0.5, 1.0)},
                        {"ParameterID": "HapticSharpness", "ParameterValue": np.random.uniform(0.5, 1.0)}
                    ]
                }
            }
            if event_type == "HapticContinuous":
                event["Event"]["EventDuration"] = width
            ahap_data["Pattern"].append(event)

        # Optionally update a status or debug message here if needed
        self.status.set("AHAP data updated.")
        
if __name__ == "__main__":
    root = tk.Tk()
    app = AHAPApplication(root)
    root.mainloop()





