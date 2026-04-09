use_bpm 60

# Global variables
$instrument_ids = []
$instrument_data = []
$pending_instruments = []
$clear_requested = false
$active_instruments = {}
$kill_all = false

# Enter location of instruments folder, e.g. "C:/Users/userx/Documents/instruments"
$sample_base_path = " "

# Instrument selection matrix (pitch x timbre)
$instrument_matrix = [
  ["chime", "xylophone", "violin", "piccolo", "flute"],      # High pitch
  ["cornet", "banjo", "ukelele", "alt-sax", "kazoo"],        # Medium-high pitch
  ["trumpet", "klavecimbal", "acoustic-guitar", "piano", "harp"], # Medium pitch
  ["trombone", "electric-guitar", "fagot", "organ", "classic-guitar"], # Medium-low pitch
  ["timpani", "acoustic-bass", "cello", "bass-guitar", "tuba"] # Low pitch
]

# Melody patterns in C major scale (rpitch values: 0=C, 2=D, 4=E, 5=F, 7=G, 9=A, 11=B)
$melody_patterns = {
  :very_slow => [
    [0, 4, 7, 0],     # C, E, G, C
    [0, 7, 4, 0],     # C, G, E, C
    [4, 7, 11, 4]     # E, G, B, E
  ],
  
  :slow => [
    [0, 2, 4, 7, 9, 7],  # C, D, E, G, A, G
    [7, 5, 4, 2, 0, 2],  # G, F, E, D, C, D
    [4, 7, 9, 11, 9, 7]  # E, G, A, B, A, G
  ],
  
  :medium => [
    [0, 4, 7, 4, 0, 7, 9, 7],    # C, E, G, E, C, G, A, G
    [7, 9, 11, 9, 7, 4, 2, 0],   # G, A, B, A, G, E, D, C
    [4, 2, 0, 4, 7, 5, 4, 2]     # E, D, C, E, G, F, E, D
  ],
  
  :fast => [
    [0, 2, 0, 4, 2, 4, 0, 7, 2, 7, 4, 7],    # C, D, C, E, D, E, C, G, D, G, E, G
    [7, 5, 7, 9, 5, 9, 7, 4, 5, 4, 2, 0],    # G, F, G, A, F, A, G, E, F, E, D, C
    [0, 4, 2, 7, 4, 0, 9, 2, 4, 2, 0, 4]     # C, E, D, G, E, C, A, D, E, D, C, E
  ],
  
  :very_fast => [
    [0, 2, 4, 0, 2, 7, 4, 2, 0, 9, 4, 7, 2, 4, 0, 2],      # C, D, E, C, D, G, E, D, C, A, E, G, D, E, C, D
    [7, 9, 5, 7, 4, 9, 7, 5, 4, 2, 7, 4, 9, 7, 5, 4],      # G, A, F, G, E, A, G, F, E, D, G, E, A, G, F, E
    [4, 0, 2, 4, 7, 2, 4, 0, 7, 4, 2, 7, 0, 4, 2, 0]       # E, C, D, E, G, D, E, C, G, E, D, G, C, E, D, C
  ]
}

# C major chord progressions
$chord_progressions = [
  (ring chord(:c3, :major), chord(:g3, :major), chord(:a3, :minor), chord(:f3, :major)),
  (ring chord(:c3, :major), chord(:f3, :major), chord(:g3, :major), chord(:c3, :major)),
  (ring chord(:c3, :major), chord(:a3, :minor), chord(:f3, :major), chord(:g3, :major))
]
$current_progression = 0

# Clamp function
define :clamp do |value, min, max|
  [[value, min].max, max].min
end

# Calculate stereo balance from left/right volumes
define :calculate_stereo_balance do |left_vol, right_vol|
  total = left_vol + right_vol
  if total == 0
    0.0  # Center if both are 0
  else
    # Returns -1 (full left) to 1 (full right)
    (right_vol - left_vol).to_f / total
  end
end

# Calculate overall volume from left/right volumes
define :calculate_total_volume do |left_vol, right_vol|
  # Use the maximum of left/right volume as the overall volume
  [left_vol, right_vol].max / 40.0
end

# Instrument selection
define :select_instrument do |pitch, timbre|
  $instrument_matrix[pitch][timbre]
end

define :get_note_duration_file do |tempo|
  case tempo
  when 4.0 then "whole"
  when 2.0 then "half"
  when 1.0 then "quarter"
  when 0.5 then "eighth"
  when 0.25 then "sixteenth"
  else "quarter"
  end
end

# Melody generation
define :get_tempo_category do |tempo|
  case tempo
  when 4.0 then :very_slow    # whole notes
  when 2.0 then :slow         # half notes
  when 1.0 then :medium       # quarter notes
  when 0.5 then :fast         # eighth notes
  else :very_fast                  # sixteenth notes
  end
end

define :get_melody_pattern do |tempo|
  $melody_patterns[get_tempo_category(tempo)].choose
end

# Instrument manager
define :process_pending_instruments do
  # Add new instruments
  $pending_instruments.each do |inst|
    id = inst[:id]
    if $instrument_ids.include?(id)
      index = $instrument_ids.index(id)
      $instrument_data[index] = inst
    else
      $instrument_ids.push(id)
      $instrument_data.push(inst)
    end
  end
  $pending_instruments.clear
  
  if $clear_requested
    $instrument_ids.clear
    $instrument_data.clear
    $clear_requested = false
    $kill_all = true
  end
end

define :get_current_instruments do
  process_pending_instruments
  $instrument_ids.each_with_index.map { |id, i| [id, $instrument_data[i]] }
end

define :stop_all_instruments do
  $clear_requested = true
  $pending_instruments.clear
end

# Instrument player
define :play_single_instrument do |id, inst|
  use_bpm 60
  
  pitch = inst[:pitch]
  timbre = inst[:timbre]
  tempo = inst[:tempo]
  left_volume = inst[:left_volume]
  right_volume = inst[:right_volume]
  
  # Calculate volume
  stereo_balance = calculate_stereo_balance(left_volume, right_volume)
  total_volume = calculate_total_volume(left_volume, right_volume)
  
  # Select instrument
  instrument_name = select_instrument(pitch, timbre)
  duration_file = get_note_duration_file(tempo)
  sample_path = "#{$sample_base_path}/#{instrument_name}/#{duration_file}.mp3"
  
  # Choose melody pattern
  melody_pattern = get_melody_pattern(tempo)
  sleep_time = tempo
  
  puts "Instrument #{id}: #{instrument_name}, #{total_volume.round(2)} vol, #{tempo}s tempo"
  puts "Stereo: L=#{left_volume}% R=#{right_volume}% balance=#{stereo_balance.round(2)}"
  puts "Chosen pattern: #{melody_pattern}"
  
  in_thread do
    note_index = 0
    
    while true
      break if $kill_all || !$instrument_ids.include?(id)
      
      rpitch_value = melody_pattern[note_index]
      
      # Convert rpitch value to rate
      rate_value = 2.0 ** (rpitch_value / 12.0)
      
      # Play sample
      sample sample_path,
        rate: rate_value,
        amp: total_volume * 0.8,
        pan: stereo_balance
      
      # Play melody
      note_index = (note_index + 1) % melody_pattern.length
      
      if note_index == 0 && one_in(4)
        $current_progression = ($current_progression + 1) % $chord_progressions.length
      end
      
      sleep sleep_time
    end
  end
end

# Loops
live_loop :manage_instruments do
  current_instruments = get_current_instruments
  
  # Start new instruments
  current_instruments.each do |id, inst|
    unless $active_instruments[id]
      $active_instruments[id] = true
      play_single_instrument(id, inst)
    end
  end
  
  # Clean up stopped instruments
  $active_instruments.each_key do |id|
    unless current_instruments.map(&:first).include?(id)
      $active_instruments.delete(id)
    end
  end
  
  $kill_all = false if $kill_all && !$clear_requested
  sleep 1
end

# OSC input
live_loop :osc_instruments do
  use_real_time
  id, pitch, timbre, tempo, left_volume, right_volume = sync "/osc*/instrument"
  $pending_instruments.push({
                              id: id,
                              pitch: pitch,
                              timbre: timbre,
                              tempo: tempo,
                              left_volume: left_volume,
                              right_volume: right_volume
  })
  puts "OSC: Instrument #{id} - pitch:#{pitch} timbre:#{timbre} tempo:#{tempo} L:#{left_volume}% R:#{right_volume}%"
end

live_loop :osc_clear do
  use_real_time
  sync "/osc*/clear"
  puts "Clearing all instruments"
  stop_all_instruments
end

live_loop :osc_stop_instrument do
  use_real_time
  id = sync("/osc*/stop_instrument")[0]
  index = $instrument_ids.index(id)
  if index
    $instrument_ids.delete_at(index)
    $instrument_data.delete_at(index)
    $active_instruments.delete(id)
    puts "Stopped instrument #{id}"
  end
end

# Status
live_loop :status_report do
  current = get_current_instruments
  if current.any?
    puts "Active: #{current.length} instruments"
  else
    puts "Waiting for instruments..."
  end
  sleep 4
end