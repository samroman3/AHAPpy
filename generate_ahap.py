
import argparse
import json
import librosa
import numpy as np
from pydub import AudioSegment

def convert_wav_to_ahap(input_wav, output_ahap):
    try:
        # Load audio file using pydub
        audio = AudioSegment.from_file(input_wav, format="wav")

        # Convert to mono and set sample rate to 44.1 kHz
        audio = audio.set_channels(1).set_frame_rate(44100)

        # Convert to numpy array
        audio_data = np.array(audio.get_array_of_samples())

        # Convert to float32 in the range [-1, 1]
        audio_data = audio_data.astype(np.float32) / 32768.0

        sample_rate = audio.frame_rate

        # Generate AHAP content with both transient and continuous events
        ahap_data = generate_ahap(audio_data, sample_rate)

        # Write AHAP content to file
        with open(output_ahap, 'w') as f:
            json.dump(ahap_data, f, indent=4)

        print(f"AHAP file '{output_ahap}' generated successfully.")
    except Exception as e:
        print("Error:", e)

def generate_ahap(audio_data, sample_rate):
    """
    Generate AHAP content with both transient and continuous events.
    """
    pattern = []

    # Detect onsets
    onsets = librosa.onset.onset_detect(y=audio_data, sr=sample_rate)

    # Convert onsets to time
    event_times = librosa.frames_to_time(onsets, sr=sample_rate)

    for time in event_times:
        # Determine event type based on audio features
        haptic_mode = determine_haptic_mode(audio_data, time, sample_rate)
        if haptic_mode in ['transient', 'both']:
            event = create_event("HapticTransient", time, audio_data, sample_rate)
            pattern.append(event)
        if haptic_mode in ['continuous', 'both']:
            event = create_event("HapticContinuous", time, audio_data, sample_rate)
            pattern.append(event)

    ahap_data = {"Version": 1.0, "Pattern": pattern}
    return ahap_data

def create_event(event_type, time, audio_data, sample_rate):
    """
    Create an event with appropriate parameters based on event type and audio features.
    """
    intensity, sharpness = calculate_parameters(audio_data, time, sample_rate)
    event = {
        "Event": {
            "Time": float(time),
            "EventType": event_type,
            "EventParameters": [
                {"ParameterID": "HapticIntensity", "ParameterValue": intensity},
                {"ParameterID": "HapticSharpness", "ParameterValue": sharpness}
            ]
        }
    }
    if event_type == "HapticContinuous":
        event["Event"]["EventDuration"] = 0.1  # Adjust duration as needed
    return event

def determine_haptic_mode(audio_data, time, sample_rate):
    """
    Determine whether to use transient, continuous, or both haptic modes based on audio features.
    """
    # Calculate RMS energy in a small window around the specified time
    window_size = int(sample_rate * 0.02)  # 20 ms window
    start_index = max(0, int((time - 0.01) * sample_rate))  # Start 10 ms before the specified time
    end_index = min(len(audio_data), start_index + window_size)
    energy = np.sqrt(np.mean(audio_data[start_index:end_index] ** 2))

    # Calculate spectral centroid in a small window around the specified time
    window_size = int(sample_rate * 0.05)  # 50 ms window
    start_index = max(0, int((time - 0.025) * sample_rate))  # Start 25 ms before the specified time
    end_index = min(len(audio_data), start_index + window_size)
    spectral_centroid = librosa.feature.spectral_centroid(
        y=audio_data[start_index:end_index], sr=sample_rate
    )

    # Get mean value of spectral centroid for comparison
    spectral_centroid_mean = np.mean(spectral_centroid)

    # Adjust thresholds
    transient_rms_threshold = 0.5  # Increased threshold for transient mode
    continuous_rms_threshold = 0.2  # Decreased threshold for continuous mode
    spectral_threshold = np.percentile(spectral_centroid, 90)  # Higher threshold for transient mode

    # Classify based on a combination of features
    if energy > transient_rms_threshold and spectral_centroid_mean > spectral_threshold:
        return 'transient'
    elif energy < continuous_rms_threshold:
        return 'continuous'
    else:
        return 'both'

def calculate_parameters(audio_data, time, sample_rate):
    # Calculate RMS energy in a small window around the specified time
    window_size = int(sample_rate * 0.02)  # 20 ms window
    start_index = max(0, int((time - 0.01) * sample_rate))  # Start 10 ms before the specified time
    end_index = min(len(audio_data), start_index + window_size)
    energy = np.sqrt(np.mean(audio_data[start_index:end_index] ** 2))

    # Calculate spectral centroid in a small window around the specified time
    window_size = int(sample_rate * 0.05)  # 50 ms window
    start_index = max(0, int((time - 0.025) * sample_rate))  # Start 25 ms before the specified time
    end_index = min(len(audio_data), start_index + window_size)
    spectral_centroid = librosa.feature.spectral_centroid(
        y=audio_data[start_index:end_index], sr=sample_rate
    )

    # Calculate sharpness based on the spectral centroid
    sharpness = np.mean(spectral_centroid)

    # Scale the energy to the range [0, 1] with a minimum value of 0.5
    scaled_energy = max(energy / 1000, 0.5)

    # Add random noise to the scaled energy to introduce variability
    noise = np.random.normal(loc=0, scale=0.1) 
    scaled_energy += noise
    scaled_energy = np.clip(scaled_energy, 0, 1)  # Clip to ensure intensity is within valid range

    return scaled_energy, sharpness

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert WAV file to AHAP format")
    parser.add_argument("input_wav", help="Input WAV file path")
    parser.add_argument("output_ahap", help="Output AHAP file path")
    args = parser.parse_args()

    convert_wav_to_ahap(args.input_wav, args.output_ahap)
