# AHAPpy
<img src="https://github.com/samroman3/AHAPpy/assets/52180475/40fcaf33-45c9-4dbd-93c7-f8f8057d3125" width="200" height="200">



## Audio to AHAP Converter

A Python script that converts audio files (WAV, MP3, OGG etc.) to AHAP (Apple Haptic Audio Pattern) format, which can be used to synchronize audio and haptic effects in games, virtual reality experiences, and interactive multimedia. With a simple GUI, AHAPpyUI.py, to streamline the conversion process. A sample iOS app is available with an example implementation.

## Inspiration

This project was inspired by Lofelt's [NiceVibrations](https://github.com/Lofelt/NiceVibrations), which offers advanced haptic feedback solutions for various applications. I felt a need for an even simpler implementation of haptic-audio synchronization that focused specifically on iOS development, leading to the creation of this AHAP converter.

## Requirements
- Python 3.x
- [NumPy](https://numpy.org/)
- [Librosa](https://librosa.org/)
- [PyDub](https://github.com/jiaaro/pydub)
- [tkinter](https://docs.python.org/3/library/tkinter.html) - for GUI


You can install the dependencies using pip:

```bash
pip install numpy librosa pydub tkinter
```
or install using the requirements:

```bash
pip install -r requirements.txt
```

## Usage
### Using generate_ahap.py

Run the script with the following command:
```bash
python generate_ahap.py input_wav [--output_dir OUTPUT_DIR] [--mode MODE] [--split SPLIT]
```

--input_wav: Path to the input WAV file.
--output_dir: Directory where the output AHAP files will be saved. Defaults to the same directory as the input WAV file.
--mode: Mode for processing the WAV file. Can be 'sfx' (sound effects) or 'music'. Defaults to 'music'.
--split: Split mode for processing. Options are 'none', 'all', 'vocal', 'drums', 'bass', 'other'. Only applicable when mode is 'music'. Defaults to 'none'.

Example:

```bash
python generate_ahap.py example.wav --mode music --split vocal
```

New AHAP files will be saved in the specified directory, or the same directory as the WAV file if no output directory is specified.

### Using AHAPpyUI.py

Alternatively, you can use the AHAPpyUI.py file, which provides a minimal GUI for the conversion process.
```bash
python AHAPpyUI.py
```
<img width="780" alt="Screenshot 2024-05-18 at 9 23 49 PM" src="https://github.com/samroman3/AHAPpy/assets/52180475/99dc5b2a-9547-40c0-adb7-55ce5c1641d5">

## Features
- Transient and Continuous Events: The AHAP file contains both transient and continuous haptic events, synchronized with the audio content.
- Dynamic Parameter Calculation: Haptic parameters such as intensity and sharpness are calculated dynamically based on audio features.
- Customizable Parameters: You can adjust thresholds and window sizes to customize the conversion process according to your requirements.
- Music Mode and Splits: In music mode, you can specify different splits such as 'vocal', 'drums', 'bass', and 'other' to process specific components of the audio.
  
### How It Works
The conversion process involves the following steps:
1. Load Audio: The input WAV file is loaded using PyDub and converted to a NumPy array.
2. Feature Extraction: Audio features such as onsets and spectral centroid are extracted using Librosa.
3. Event Generation: Transient and continuous haptic events are generated based on the audio features.
4. Parameter Calculation: Haptic parameters such as intensity and sharpness are calculated dynamically.
5. Output AHAP: The AHAP content is written in JSON format and saved to same directory as the input file.
 
If AHAPpy has helped you in your own projects I would love to hear about it! If you have any questions, feedback, or suggestions for improvement, feel free to reach out.

<a href="https://www.ko-fi.com/samroman" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>

