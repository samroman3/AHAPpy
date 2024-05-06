# AHAPpy
## WAV to AHAP Converter

A simple Python script that converts WAV files to AHAP (Audio Haptic Pattern) format, which can be used to synchronize audio and haptic effects in applications such as games, virtual reality experiences, and interactive multimedia. Additionally, you can utilize the AHAPpyUI.py file to streamline the conversion process in a simple GUI.

## Inspiration

This project was inspired by Lofelt's [NiceVibrations](https://github.com/Lofelt/NiceVibrations), which offers advanced haptic feedback solutions for various applications. I felt a need for an even simpler lightweight implementation of haptic-audio synchronization that focused specifically on iOS development, leading to the creation of this WAV to AHAP converter.

## Requirements
- Python 3.x
- [NumPy](https://numpy.org/)
- [LibROSA](https://librosa.org/)
- [PyDub](https://github.com/jiaaro/pydub)
- [tkinter](https://docs.python.org/3/library/tkinter.html) - for GUI


You can install the dependencies using pip:

```bash
pip install numpy librosa pydub tkinter
```

## Usage
### Using generate_ahap.py

Run the script with the following command:
```bash
python generate_ahap.py input_wav output_ahap
```

*input_wav*: Path to the input WAV file.

*output_ahap*: Path to the output AHAP file.

New AHAP files will be saved in the same directory as the WAV file.

### Using AHAPpyUI.py

Alternatively, you can use the AHAPpyUI.py file, which provides a minimal GUI for the conversion process.
```bash
python AHAPpyUI.py
```

## Features
- Transient and Continuous Events: The AHAP file contains both transient and continuous haptic events, synchronized with the audio content.
- Dynamic Parameter Calculation: Haptic parameters such as intensity and sharpness are calculated dynamically based on audio features.
- Customizable Parameters: You can adjust thresholds and window sizes to customize the conversion process according to your requirements.
  
### How It Works
The conversion process involves the following steps:
1. Load Audio: The input WAV file is loaded using PyDub and converted to a NumPy array.
2. Feature Extraction: Audio features such as onsets and spectral centroid are extracted using LibROSA.
3. Event Generation: Transient and continuous haptic events are generated based on the audio features.
4. Parameter Calculation: Haptic parameters such as intensity and sharpness are calculated dynamically.
5. Output AHAP: The AHAP content is written to a JSON file.

If you have any questions, feedback, or suggestions for improvement, feel free to reach out. 

