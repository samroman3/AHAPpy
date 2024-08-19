import argparse
import json
import librosa
import numpy as np
from pydub import AudioSegment
import time
import os
from tqdm import tqdm
from concurrent.futures import ThreadPoolExecutor

def convert_wav_to_ahap(input_wav, output_dir, mode, split):
    try:
        # Start timing
        start_time = time.time()

        # Load audio file using pydub
        audio = AudioSegment.from_file(input_wav, format=os.path.splitext(input_wav)[-1][1:])

        # Convert to mono and set sample rate to 44.1 kHz
        audio = audio.set_channels(1).set_frame_rate(44100)

        # Convert to numpy array
        audio_data = np.array(audio.get_array_of_samples())

        # Convert to float32 in the range [-1, 1]
        audio_data = audio_data.astype(np.float32) / 32768.0

        sample_rate = audio.frame_rate
        duration = len(audio_data) / sample_rate

        with ThreadPoolExecutor() as executor:
            # Perform HPSS once
            future_hpss = executor.submit(librosa.effects.hpss, audio_data)

            # Isolate bass using a low-pass filter
            future_bass = executor.submit(librosa.effects.hpss, audio_data, margin=(1.0, 20.0))

            # Retrieve results
            harmonic, percussive = future_hpss.result()
            bass = future_bass.result()[0]

        # Use the directory of the input WAV file if output_dir is not provided
        if not output_dir:
            output_dir = os.path.dirname(input_wav)

        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)

        output_files = []

        if split == "none":
            ahap_data = generate_ahap(audio_data, sample_rate, mode, harmonic, percussive, bass, duration, split)
            output_ahap = os.path.join(output_dir, os.path.basename(input_wav).replace(os.path.splitext(input_wav)[-1], '_combined.ahap'))
            write_ahap_file(output_ahap, ahap_data)
            output_files.append(output_ahap)
        else:
            splits = ['bass', 'vocals', 'drums', 'other']
            for split_type in splits:
                if split != "all" and split != split_type:
                    continue
                ahap_data = generate_ahap(audio_data, sample_rate, mode, harmonic, percussive, bass, duration, split_type)
                output_ahap = os.path.join(output_dir, os.path.basename(input_wav).replace(os.path.splitext(input_wav)[-1], f'_{split_type}.ahap'))
                write_ahap_file(output_ahap, ahap_data)
                output_files.append(output_ahap)

        # End timing
        end_time = time.time()
        elapsed_time = end_time - start_time

        print(f"AHAP files generated successfully in {elapsed_time:.2f} seconds.")
        print("Generated files:")
        for file in output_files:
            print(f" - {file}")
    except Exception as e:
        print("Error:", e)

def write_ahap_file(output_ahap, ahap_data):
    # Write AHAP content to file
    with open(output_ahap, 'w') as f:
        json.dump(ahap_data, f, indent=4)

def generate_ahap(audio_data, sample_rate, mode, harmonic, percussive, bass, duration, split):
    """
    Generate AHAP content with both transient and continuous events.
    """
    pattern = []

    # Detect onsets for transients
    onsets = librosa.onset.onset_detect(y=audio_data, sr=sample_rate)

    # Convert onsets to time
    event_times = librosa.frames_to_time(onsets, sr=sample_rate)

    # Create progress bar for transient events
    with tqdm(total=len(event_times), desc="Processing transient events") as pbar:
        for time in event_times:
            # Determine event type based on audio features
            haptic_mode = determine_haptic_mode(audio_data, time, sample_rate, mode, harmonic, percussive, bass)
            if haptic_mode in ['transient', 'both']:
                event = create_event("HapticTransient", time, audio_data, sample_rate, split)
                pattern.append(event)
            if haptic_mode in ['continuous', 'both']:
                event = create_event("HapticContinuous", time, audio_data, sample_rate, split)
                pattern.append(event)
            pbar.update(1)

    # Add continuous events for bass and harmonic components
    add_continuous_events(pattern, audio_data, sample_rate, harmonic, bass, duration, split)

    ahap_data = {"Version": 1.0, "Pattern": pattern}
    return ahap_data

def create_event(event_type, time, audio_data, sample_rate, split):
    """
    Create an event with appropriate parameters based on event type and audio features.
    """
    intensity, sharpness = calculate_parameters(audio_data, time, sample_rate, split)
    event = {
        "Event": {
            "Time": float(time),
            "EventType": event_type,
            "EventParameters": [
                {"ParameterID": "HapticIntensity", "ParameterValue": float(intensity)},
                {"ParameterID": "HapticSharpness", "ParameterValue": float(sharpness)}
            ]
        }
    }
    if event_type == "HapticContinuous":
        event["Event"]["EventDuration"] = 0.1  # Adjust duration as needed
    return event

def determine_haptic_mode(audio_data, time, sample_rate, mode, harmonic, percussive, bass):
    """
    Determine whether to use transient, continuous, or both haptic modes based on audio features.
    """
    # Calculate RMS energy in a small window around the specified time
    window_size = int(sample_rate * 0.02)  # 20 ms window
    start_index = max(0, int((time - 0.01) * sample_rate))  # Start 10 ms before the specified time
    end_index = min(len(audio_data), start_index + window_size)
    energy = np.sqrt(np.mean(audio_data[start_index:end_index] ** 2))

    # Calculate sub-band energies using pre-computed harmonic, percussive, and bass components
    bass_energy = np.sqrt(np.mean(bass[start_index:end_index] ** 2))
    percussive_energy = np.sqrt(np.mean(percussive[start_index:end_index] ** 2))
    harmonic_energy = np.sqrt(np.mean(harmonic[start_index:end_index] ** 2))

    # Calculate spectral centroid in a small window around the specified time
    window_size = int(sample_rate * 0.05)  # 50 ms window
    start_index = max(0, int((time - 0.025) * sample_rate))  # Start 25 ms before the specified time
    end_index = min(len(audio_data), start_index + window_size)
    spectral_centroid = librosa.feature.spectral_centroid(
        y=audio_data[start_index:end_index], sr=sample_rate
    )

    # Calculate additional features
    zcr = librosa.feature.zero_crossing_rate(y=audio_data[start_index:end_index])
    spectral_rolloff = librosa.feature.spectral_rolloff(y=audio_data[start_index:end_index], sr=sample_rate)
    mfccs = librosa.feature.mfcc(y=audio_data[start_index:end_index], sr=sample_rate, n_mfcc=13)

    # Get mean value of spectral centroid for comparison
    spectral_centroid_mean = np.mean(spectral_centroid)
    zcr_mean = np.mean(zcr)
    spectral_rolloff_mean = np.mean(spectral_rolloff)
    mfcc_mean = np.mean(mfccs, axis=1)

    # Adjust thresholds based on the mode
    if mode == 'sfx':
        transient_rms_threshold = 0.5
        continuous_rms_threshold = 0.2
        spectral_threshold = np.percentile(spectral_centroid, 90)
    else:  # music
        transient_rms_threshold = 0.2
        continuous_rms_threshold = 0.1
        spectral_threshold = np.percentile(spectral_centroid, 70)

    # Classify based on a combination of features
    if energy > transient_rms_threshold and spectral_centroid_mean > spectral_threshold:
        return 'transient'
    elif energy < continuous_rms_threshold:
        return 'continuous'
    else:
        return 'both'

def calculate_parameters(audio_data, time, sample_rate, split):
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

    # Scale the energy to the range [0, 1]
    scaled_energy = np.clip(energy / np.max(audio_data), 0, 1)

    # Increase the overall intensity to add more "oomph"
    scaled_energy *= 1.5
    scaled_energy = np.clip(scaled_energy, 0, 1)

    # Scale sharpness to a range that fits the haptic feedback parameters
    scaled_sharpness = np.clip(sharpness / np.max(spectral_centroid), 0, 1)

    # Adjust parameters based on split type
    if split == "vocal":
        scaled_energy *= 1.2
        scaled_sharpness *= 1.1
    elif split == "drums":
        scaled_energy *= 1.5
        scaled_sharpness *= 1.3
    elif split == "bass":
        scaled_energy *= 1.4
        scaled_sharpness *= 0.9
    elif split == "other":
        scaled_energy *= 1.3
        scaled_sharpness *= 1.2

    return scaled_energy, scaled_sharpness

def add_continuous_events(pattern, audio_data, sample_rate, harmonic, bass, duration, split):
    """
    Add continuous haptic events for bass and harmonic components.
    """
    time_step = 0.1  # Adjust time step for continuous events
    num_steps = int(duration / time_step)

    # Create progress bar for continuous events
    with tqdm(total=num_steps, desc="Processing continuous events") as pbar:
        for t in np.arange(0, duration, time_step):
            bass_energy = np.sqrt(np.mean(bass[int(t * sample_rate):int((t + time_step) * sample_rate)] ** 2))
            harmonic_energy = np.sqrt(np.mean(harmonic[int(t * sample_rate):int((t + time_step) * sample_rate)] ** 2))

            # Calculate intensity and sharpness
            intensity = np.clip(bass_energy / np.max(bass), 0, 1) * 1.5
            intensity = np.clip(intensity, 0, 1)
            sharpness = np.clip(harmonic_energy / np.max(harmonic), 0, 1)

            event = {
                "Event": {
                    "Time": float(t),
                    "EventType": "HapticContinuous",
                    "EventDuration": time_step,
                    "EventParameters": [
                        {"ParameterID": "HapticIntensity", "ParameterValue": float(intensity)},
                        {"ParameterID": "HapticSharpness", "ParameterValue": float(sharpness)}
                    ]
                }
            }
            pattern.append(event)
            pbar.update(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert WAV file to AHAP format")
    parser.add_argument("input_wav", help="Input WAV file path")
    parser.add_argument("--output_dir", help="Output directory for AHAP files", default=None)
    parser.add_argument("--mode", choices=['sfx', 'music'], default='music', help="Mode for processing: 'sfx' or 'music'")
    parser.add_argument("--split", choices=['none', 'all', 'vocal', 'drums', 'bass', 'other'], default='none', help="Split mode for processing: 'none', 'all', 'vocal', 'drums', 'bass', 'other'")
    args = parser.parse_args()

    convert_wav_to_ahap(args.input_wav, args.output_dir, args.mode, args.split)
