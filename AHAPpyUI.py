import tkinter as tk
from tkinter import filedialog, messagebox, Menu, ttk
import os
import generate_ahap

class AHAPApplication:
    def __init__(self, master):
        self.master = master
        self.master.title("AHAPpy")
        self.master.geometry("500x250")
        self.master.minsize(500, 250)

        self.master.iconphoto(False, tk.PhotoImage(file='app_icon.png'))

        self.set_dark_mode()

        menu = Menu(master, bg="#2e2e2e", fg="#ffffff", activebackground="#444444", activeforeground="#ffffff")
        master.config(menu=menu, bg="#2e2e2e")

        file_menu = Menu(menu, tearoff=0, bg="#2e2e2e", fg="#ffffff", activebackground="#444444", activeforeground="#ffffff")
        menu.add_cascade(label="File", menu=file_menu)
        file_menu.add_command(label="Open WAV", command=self.open_wav)

        self.status = tk.StringVar()
        self.status_bar = ttk.Label(master, textvariable=self.status, relief=tk.SUNKEN, anchor=tk.W, background="#2e2e2e", foreground="#ffffff")
        self.status_bar.pack(side=tk.BOTTOM, fill=tk.X)

        control_frame = ttk.Frame(self.master, style='TFrame')
        control_frame.pack(side=tk.TOP, fill=tk.X, padx=10, pady=10)

        ttk.Label(control_frame, text="Mode:", style='TLabel').pack(side=tk.LEFT, padx=5)
        self.mode_var = tk.StringVar(value='music')
        mode_menu = ttk.Combobox(control_frame, textvariable=self.mode_var, values=['sfx', 'music'], state='readonly', style='TCombobox')
        mode_menu.pack(side=tk.LEFT, padx=5)
        mode_menu.bind("<<ComboboxSelected>>", self.toggle_split_menu)

        self.split_label = ttk.Label(control_frame, text="Split:", style='TLabel')
        self.split_var = tk.StringVar(value='none')
        self.split_menu = ttk.Combobox(control_frame, textvariable=self.split_var, values=['none', 'all', 'vocal', 'drums', 'bass', 'other'], state='readonly', style='TCombobox')

        if self.mode_var.get() == 'music':
            self.split_label.pack(side=tk.LEFT, padx=5)
            self.split_menu.pack(side=tk.LEFT, padx=5)

        convert_button = ttk.Button(self.master, text="Convert WAV to AHAP", command=self.open_wav, style='TButton')
        convert_button.pack(pady=20)

        self.set_dock_name("AHAPpy")

    def set_dock_name(self, name):
        try:
            import subprocess
            apple_script = f'''
            tell application "System Events"
                set frontmost of the first process whose unix id is {os.getpid()} to true
                set name of the first process whose unix id is {os.getpid()} to "{name}"
            end tell
            '''
            subprocess.run(["osascript", "-e", apple_script])
        except Exception as e:
            print(f"Could not set dock name: {e}")

    def set_dark_mode(self):
        style = ttk.Style()
        style.theme_use('clam')

        style.configure('TFrame', background='#2e2e2e')
        style.configure('TLabel', background='#2e2e2e', foreground='#ffffff', font=('Helvetica', 14))
        style.configure('TButton', background='#444444', foreground='#ffffff', font=('Helvetica', 14), relief='flat')
        style.map('TButton', background=[('active', '#666666')])
        style.configure('TCombobox', fieldbackground='#444444', background='#2e2e2e', foreground='#ffffff', font=('Helvetica', 14))
        style.map('TCombobox', fieldbackground=[('readonly', '#444444')], background=[('readonly', '#2e2e2e')], foreground=[('readonly', '#ffffff')])

    def toggle_split_menu(self, event):
        if self.mode_var.get() == 'music':
            self.split_label.pack(side=tk.LEFT, padx=5)
            self.split_menu.pack(side=tk.LEFT, padx=5)
        else:
            self.split_label.pack_forget()
            self.split_menu.pack_forget()

    def open_wav(self):
        file_path = filedialog.askopenfilename(filetypes=[("WAV files", "*.wav")])
        if file_path:
            try:
                self.status.set("Converting WAV to AHAP...")
                output_dir = os.path.dirname(file_path)
                mode = self.mode_var.get()
                split = self.split_var.get() if self.mode_var.get() == 'music' else 'none'
                generate_ahap.convert_wav_to_ahap(file_path, output_dir, mode, split)
                output_ahap = os.path.join(output_dir, os.path.splitext(os.path.basename(file_path))[0] + '_combined.ahap')
                if os.path.exists(output_ahap):
                    self.status.set("Conversion complete. AHAP file saved.")
                else:
                    self.status.set("Conversion failed. AHAP file not found.")
            except Exception as e:
                messagebox.showerror("Conversion Failed", str(e))
                self.status.set("Error during conversion.")

if __name__ == "__main__":
    root = tk.Tk()
    app = AHAPApplication(root)
    root.mainloop()
