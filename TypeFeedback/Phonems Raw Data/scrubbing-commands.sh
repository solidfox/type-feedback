#!fish
mkdir scrubbed
for file in *
  ffmpeg -i $file -af "silenceremove=start_periods=1:start_duration=0:start_threshold=-60dB:stop_periods=1:stop_threshold=-85dB, volume=13" scrubbed/$file
end
