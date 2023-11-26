#!/bin/bash

USE_HEADSET_MIC=1

function get_playback_sink_input_id() {
  get_playback_id sink-inputs 'Sink Input' "$1"
}

function get_playback_source_output_id() {
  get_playback_id source-outputs 'Source Output' "$1"
}

function get_playback_id() {
  local last_node_name=''
  local last_node_id=''
  pactl list "$1" | while read -r line; do
    node_id=$(echo "$line" | grep -oP "$2 #\K.+" | sed -e 's/^[ \t]*//')
    node_name=$(echo "$line" | grep -oP 'node.name = "\K[^"]+' | sed -e 's/^[ \t]*//')
    if [[ "$node_id" != '' ]] && [[ "$last_node_id" != "$node_id" ]]; then
      last_node_id="$node_id"
    fi
    if [[ -n "$node_name" ]] && [[ "$last_node_name" != "$node_name" ]]; then
      last_node_name="$node_name"
      if [[ "$last_node_name" == "$3" ]]; then
        echo "$last_node_id"
        return
      fi
    fi
  done
}

function get_sink_id_by_name() {
  local sink_name
  sink_name=$1
  pactl list short sinks | grep "$sink_name" | cut -d$'\t' -f1
}

function setup_mic() {
  echo "Creating microphone sink & source and linking alvr playback to it"
  # This sink is required so that it persistently auto-connects to alvr playback later
  pactl load-module module-null-sink sink_name=ALVR-MIC-Sink media.class=Audio/Sink | tee -a /tmp/alvr-audio
  # This source is required so that any app can use it as microphone
  pactl load-module module-null-sink sink_name=ALVR-MIC-Source media.class=Audio/Source/Virtual | tee -a /tmp/alvr-audio
  # We link them together
  pw-link ALVR-MIC-Sink ALVR-MIC-Source
  # And we assign playback of pipewire alsa playback to created alvr sink
  pactl move-sink-input "$(get_playback_sink_input_id alsa_playback.vrserver)" "$(get_sink_id_by_name ALVR-MIC-Sink)"
  if [[ $USE_HEADSET_MIC == 1 ]]; then
    pactl set-default-source ALVR-MIC-Source
  fi
}

function unload_modules() {
  echo "Unloading audio, microphone sink & source"
  while read -r line; do
    pactl unload-module "$line"
  done <"/tmp/alvr-audio"
  >/tmp/alvr-audio
}

function setup_audio() {
  echo "Setting up audio"
  pactl load-module module-null-sink sink_name=ALVR-AUDIO-Sink media.class=Audio/Sink | tee -a /tmp/alvr-audio
  pactl set-default-sink ALVR-AUDIO-Sink
  pactl move-source-output "$(get_playback_source_output_id alsa_capture.vrserver)" "$(get_sink_id_by_name ALVR-AUDIO-Sink)"
}

case $ACTION in
connect)
  unload_modules
  setup_mic
  setup_audio
  ;;
disconnect)
  unload_modules
  ;;
esac
