require 'fileutils'
require 'open3'

class Squidvid

  def initialize

    @songs = []
    @images = []
    @texts = []
    @lengths = []
    @start_points = []
    @end_points = []

    @options = {
      :num_songs => 2,                           # set options
      :quick_test => true,
      :quick_test_total_length => 14,               # seconds
      :song_base_path => '/Users/markmcdermott/Desktop/misc/lofi/playlist-',
      :font_filepath => '/Library/Fonts/Helvetica-Bold.ttf',
      :vid => '/Users/markmcdermott/Movies/youtube/long/beach-3-hr-skip-first-min.mp4',
      :quality => 'ultrafast',
      :output_base_filename => 'stream',
      :album_art_coordinates => 'W*0.036:H*0.59',    # W is screen width, w is image width (W/2-w/2:H/2-h/2 centers)
      :font_color => 'white',
      :font_size => 120,
      :text_coordinates => 'x=w*.035:y=h*.95-text_h',
      :text_line_spacing => 25,
      :temp_folder => 'temp',
      :temp_song_text_base_filename => 'tempSongTextFile', #basename of temporary text file with song name and song artist (fullname will be like tempSongTextFile-1.txt)
      :output_folder => 'output',
      :vid_skip_to_point => '0:01:00'               # means skip the first minute of the video (skips over the watermarked parts)
    }

    pre_vid_setup(options[:temp_folder], options[:output_folder])
    (0..options[:num_songs] - 1).each do |i|
      song_dir = get_song_dir(options[:song_base_path])
      song=get_song_from_dir(song_dir)
      song_path="#{song_dir}/#{song}"
      image=get_album_art(song_path, options[:temp_folder])
      text=get_song_text(song_path,i, options[:temp_folder], options[:temp_song_text_base_filename])
      length=get_length(song_path)
      start_point=get_start_point(i,@lengths)
      end_point=get_end_point(start_point,length)
      @songs[i]=song
      @images[i]=image
      @texts[i]=text
      @lengths[i]=length
      @start_points[i]=start_point
      @end_points[i]=end_point

    end

  end

  # expose options array so things like options[:num_songs] work correctly
  def options
    @options
  end


  #####################################################
  # Some necessary pre-vid setup
  #
  # Cleans up temp files in case program stopped early in the previous run.
  # Cleans up test output mp4 files.
  # Makes a blank line.
  # Creates ffmpeg-progress.log file for progress info.
  #
  # @params   none
  # @return   none
  #####################################################
  def pre_vid_setup(temp_folder, output_folder)
    check_args(temp_folder => 'is_string', output_folder => 'is_string')
    delete_temp_files(temp_folder)
    check_condition(temp_folder,'folder_empty')
    delete_test_output_files(output_folder)
    output_folder_with_zero_min_streams="#{output_folder}/stream-0-mins*"
    check_condition(output_folder_with_zero_min_streams, 'no_files_of_pattern')
    log_filepath = "#{temp_folder}/ffmpeg-progress.log"
    FileUtils.touch(log_filepath)
    check_post_conds(log_filepath => 'file_exists,file_empty')
  end

  #####################################################
  # Randomly picks one of two mp3 directories
  #
  # This is obviously custom to my setup - you will want to change this most likely.
  # I have two mp3 playlist folders: playlist-1 and playlist-2.
  # Path returned does #not* have a trailing forward slash at the end.
  #
  # @param  {String} full path to song folder, but without number at end. ie, /Users/markmcdermott/Desktop/misc/lofi/playlist-
  # @return {String} full path. ie, /Users/markmcdermott/Desktop/misc/lofi/playlist-1
  #####################################################
  def get_song_dir(song_base_path)
    check_args(song_base_path => 'var_exists,is_string')
    random_num = rand(2) + 1  # random value of 1 or 2
    check_conditions(random_num => 'var_exists,is_number,is_1_or_2')
    full_path="#{song_base_path}#{random_num}"
    check_post_conds(full_path => 'var_exists,is_string,not_empty_string')
    full_path
  end

  #####################################################
  # Randomly picks a mp3 file from a given mp3 folder
  #
  # Param path does not have trailing forward slash at end.
  #
  # @param  {String} path to mp3 folder. ie, /Users/markmcdermott/Desktop/misc/lofi/playlist-1
  # @return {String} mp3 filename with no path. ie, dancer.mp3
  #####################################################
  def get_song_from_dir(song_dir)
    check_args(song_dir => 'var_exists,is_string')
    song_with_path=Dir.glob("#{song_dir}/*").sample
    song = song_with_path.split('/')[-1]
    check_conditions(song => 'var_exists,is_string,ends_in_mp3')
    song
  end

  #####################################################
  # Randomly picks a mp3 song from one of two mp3 folders
  #
  # I have two mp3 playlist folders: playlist-1 and playlist-2 - it chooses one,
  # then randomly chooses an mp3 from that folder.
  # This is obviously custom to my setup - you will want to change this most likely.
  #
  # @return {String} mp3 filename with no path. ie, dancer.mp3
  #####################################################
  def get_song(song_base_path)
    check_args(song_base_path => 'var_exists,is_string')
    song_dir=get_song_dir(song_base_path) # you will want to tweak this unless you have the exact same two folder playlist system i do
    song=get_song_from_dir(song_dir)
    check_conditions(song => 'var_exists,is_string,ends_in_mp3')
    song
  end

  #####################################################
  # Takes in mp3 filename and returns an image filename
  #
  # Takes in something like dancer.mp3 and returns something to dancer.jpg
  #
  # @param  {String} song path and filename that ends in .mp3
  # @return {String} same base filename, but now ends in .jpg
  #####################################################
  def get_album_art_filename(song_path)
    check_args(song_path => 'var_exists,is_string,ends_in_mp3')
    song=song_path.split('/')[-1]
    base_filename=song.split('.')[0]
    image_name="#{base_filename}.png"
    check_post_conds(image_name => 'var_exists,is_string,ends_in_png')
    image_name
  end

  #####################################################
  # Creates album art png file
  #
  # Function does two things (maybe refactor into two functions):
  # 1) returns image filename. ie, coffee.png
  # 2) as a side effect, it creates png image file
  #    (in temp folder)
  #
  # @param  {String} mp3 song path/filename
  # @return {String} image filename ie, coffee.png
  #####################################################
  def get_album_art(song_path, temp_folder)
    check_args(song_path => 'var_exists,is_string,ends_in_mp3', temp_folder => 'var_exists,is_string,folder_exists')
    image_filename=get_album_art_filename(song_path)
    image_filepath="#{temp_folder}/#{image_filename}"
    check_conditions(image_filepath => 'var_exists,is_string,ends_in_png')
    cmd="ffmpeg -i #{song_path} #{image_filepath} -y -loglevel quiet" # create the album art png image
    # cmd="ffmpeg -i #{song_path} #{image_filepath} -y" # create the album art png image # for debugging
    safe_sys_call(cmd)
    check_post_conds(image_filepath => 'file_exists')
    image_filename
  end

  #####################################################
  # Get mp3 song length in seconds
  #
  # @param  {String} mp3 song path/filename
  # @return {Decimal} lenth of song as number with four decimal places
  #####################################################
  def get_length(song_path,quick_test=false,quick_test_total_length=nil)
    check_args(song_path => 'var_exists,is_string,ends_in_mp3', quick_test => 'var_exists,is_boolean', quick_test_total_length => 'if_exists_is_number')
    if quick_test == true
      half_total_length=quick_test_total_length / 2.0
      length_num=half_total_length
      length_rounded=length_num.round(4)
    else
      length_rounded = ffprobe_length_call(song_path)
    end
    check_post_conds(length_rounded => 'var_exists')
    length_rounded
  end

  #####################################################
  # Get song title
  #
  # @param  {String} mp3 song path/filename
  # @return {String} song title (all lowercase)
  #####################################################
  def get_title(song_path)
    check_args(song_path => 'var_exists,is_string,ends_in_mp3')
    title = ffprobe_title_call(song_path)
    title_lowercase = title.downcase
    check_post_conds(title_lowercase => 'var_exists,is_string')
    title_lowercase
  end

  #####################################################
  # Get artist name
  #
  # @param  {String} mp3 song path/filename
  # @return {String} artist name ie (all lowercase), ie blvk
  #####################################################
  def get_artist(song_path)
    check_args(song_path => 'var_exists,is_string,ends_in_mp3')
    artist = ffprobe_artist_call(song_path)
    artist_lowercase = artist.downcase
    check_post_conds(artist_lowercase => 'var_exists,is_string')
    artist_lowercase
  end

  #####################################################
  # Get song title and song artist
  #
  # Function does two things (maybe refactor into two functions):
  # 1) returns song title and artist ie, dancer\nblvk
  # 2) as a side effect, it writes title/artist to a temp text file
  # Writing to a text file is a hacky workaround for the way ffmpeg does not
  # handle multiline text well and does not handle spaces in text well.
  # In complex filters the line break is not parsed and the two lines
  # are just outputted like dancer\nblvk. You can put anything in the text file,
  # so these textfiles have title on one line and song on the next line.
  # Also spaces often break the whole program so a song name like
  # Dancer In The Dark would break on the first space, stopping the whole program.
  #
  # @param  {String} mp3 song path/filename
  # @param  {Integer} number of current song
  # @return {String} song title and artist as one line like "dancer\nblvk"
  #####################################################
  def get_song_text(song_path, song_num, temp_folder, temp_song_text_base_filename)
    check_args(song_path => 'var_exists,is_string,ends_in_mp3', song_num => 'var_exists,is_number,gte_0')
    title=get_title(song_path)
    check_conditions(title => 'var_exists,is_string')
    artist=get_artist(song_path)
    check_conditions(artist => 'var_exists,is_string')
    text="#{title}\n#{artist}"
    check_conditions(text => 'var_exists,is_string,not_empty_string,not_newline')
    song_num =+ 1 # zero index to one index
    text_filepath="./#{temp_folder}/#{temp_song_text_base_filename}-#{song_num}.txt"
    File.open(text_filepath, 'w') { |file| file.write(text) }   # create temp file with song title & artist (temp file is a hacky way to keep special characters like spaces from throwing an error in ffmpeg. it's also the only way to get the newline character between the title & artist to render correctly)
    check_post_conds(text_filepath => 'file_exists')
    text
  end

  #####################################################
  # Calculates song start point in seconds
  #
  # Loops through all previous songs and sums all their lengths
  # return number is the number of seconds from the start of the whole video
  # to the start point of the current song.
  # So if this is song three and the previous two songs were each 60 seconds long,
  # the start point of this song is 120.0000 seconds.
  #
  # @param  {Integer} number of songs processed so far, including current song
  # @return {Decimal} number of seconds, with four decimal places
  #####################################################
  def get_start_point(song_num,this_lengths)
    check_args(song_num => 'var_exists,is_number,gte_0')
    this_start_point=0
    (0..song_num - 1).each do |j|1
      this_start_point = this_start_point + this_lengths[j]
    end
    check_post_conds(this_start_point => 'var_exists,is_number,gte_0')
    this_start_point
  end

  #####################################################
  # Calculates song end point in seconds
  #
  # Sums start point of current song and the length of the current song.
  # Return value is number of seconds from start of whole video to end of current song.
  #
  # @param  {Decimal} start point of current song in seconds
  # @param  {Decimal} length of current song in seconds
  # @return {Decimal} end point of current song in seconds
  #####################################################
  def get_end_point(start_point, song_length)
    check_args(start_point => 'var_exists,is_number,gte_0', song_length => 'var_exists,is_number,gte_0')
    this_end_point = start_point + song_length
    check_post_conds(this_end_point => 'var_exists,is_number,gte_0')
    this_end_point
  end

  #####################################################
  # Calculates the total length of the video in seconds
  #
  # If testing boolean var quickTest is true, this just sets the
  # total length of the whole vid equal to the quickTestTotalLength variable.
  # Otherwise, it just grabs the endpoint of the last song and uses that.
  #
  # @return {Decimal} length of whole video in seconds, with four decimal places
  #####################################################
  def get_total_length(end_points, quick_test=false, quick_test_total_length=@options[:quick_test_total_length])
    if quick_test == true
      this_total_length = quick_test_total_length
    else
      this_total_length = end_points[-1]
    end
    check_post_conds(this_total_length => 'var_exists,is_number,gte_0')
    this_total_length
  end

  #####################################################
  # Gets final output mp4 filename
  #
  # Example: stream-32-mins-0616211521.mp4
  # Numbers at end of filename are MMDDYYHHMM
  #
  # @return {String} final output mp4 filename
  #####################################################
  def get_output_filename(total_length,output_base_filename,current_date_mmddyyhhmm)
    # current_date=Time.now.strftime("%m%d%y%H%M") #MMDDYYHHMM
    check_args(
      total_length => '1 var_exists,is_number,gte_0',
      output_base_filename => '2 var_exists,is_string',
      current_date_mmddyyhhmm => '3 var_exists,is_string'
    )
    if current_date_mmddyyhhmm.length != 10 || !/\A\d+\z/.match(current_date_mmddyyhhmm)
      raise ArgumentError.new("current_date_mmddyyhhmm is nil or not a string or is not 10 chars long or is not all numbers")
    end
    mins_long=total_length/60
    output_filename="#{output_base_filename}-#{mins_long}-mins-#{current_date_mmddyyhhmm}.mp4"
    check_post_conds(output_filename => 'var_exists,is_string,ends_in_mp4')
    output_filename
  end

  #####################################################
  # Get video input argument string for ffmpeg command
  #
  # -ss means "start at" (it skips to specified timestamp in HH:MM:SS format)
  # -t means duration (how long to play the vid from the start point in seconds)
  # -i is the input video filepath/filename
  # Example output: -ss 00:01:00 -t 300 -i /Users/markmcdermott/Movies/youtube/long/beach-3-hr-skip-first-min.mp4
  # See https://ffmpeg.org/ffmpeg.html#toc-Description for ffmpeg input file option details
  #
  # @return {String} ffmpeg video input argument string
  #####################################################
  def get_vid_str(vid_skip_to_point, total_length, vid_path)
    check_args(
      vid_skip_to_point => 'var_exists,is_string',
      total_length => 'var_exists,is_number,gte_0',
      vid_path => 'var_exists,is_string,ends_in_mp4'
    )
    vid_str="-ss #{vid_skip_to_point} -t #{total_length} -i #{vid_path}"
    check_post_conds(vid_str => 'var_exists,is_string,ends_in_mp4')
    vid_str
  end

  #####################################################
  # Get song input argument string for ffmpeg command
  #
  # -i is the input songs filepath/filename
  # -t means duration (how long to play the vid from the start point in seconds)
  # Example output: -i /Users/markmcdermott/Desktop/misc/lofi/playlist-1/dancer.mp3 -i /Users/markmcdermott/Desktop/misc/lofi/playlist-1/summer.mp3
  # If testing boolean var quickTest is true, this also adds a duration option,
  # so only part of the song used. It uses the length set in the length array.
  # See https://ffmpeg.org/ffmpeg.html#toc-Description for ffmpeg input file option details
  #
  # @return {String} ffmpeg songs input argument string
  #####################################################
  def get_songs_str(num_songs, song_dir, lengths, songs, quick_test=false)
    check_args(
      num_songs => 'var_exists,is_number,gte_0',
      song_dir => 'var_exists,is_string',
      lengths => 'var_exists,is_array',
      songs => 'var_exists,is_array'
    )
    input_songs_str = ''
    (0..num_songs - 1).each do |i|
      if quick_test==true
        input_songs_str += "-t #{lengths[i]} -i #{song_dir}/#{songs[i]} "
      else
        input_songs_str += "-i #{song_dir}/#{songs[i]} "
      end
    end
    check_post_conds(input_songs_str => 'var_exists,is_string')
    input_songs_str
  end

  #####################################################
  # Get images input argument string for ffmpeg command
  #
  # -i is the input images filepath/filename
  # Example output: -i dancer.jpg -i sunshine.jpg
  # See https://ffmpeg.org/ffmpeg.html#toc-Description for ffmpeg input file option details
  #
  # @param  {String} path of temp folder
  # @param  {String Array} array of image filenames (no paths, just filenames)
  # @return {String} ffmpeg images input argument string
  #####################################################
  def get_images_str(temp_folder, num_songs, images)
    check_args(
      temp_folder => 'var_exists,is_string,not_empty_string',
      num_songs => 'var_exists,is_number,gte_1',
      images => 'is_array,length_gte_1'
    )
    input_images_str = ''
    (0..num_songs - 1).each do |i|
      input_images_str += "-i #{temp_folder}/#{images[i]} "
    end
    check_post_conds(input_images_str => 'var_exists,is_string,length_gte_1')
    input_images_str
  end

  #####################################################
  # Get ffmpeg filter argument string
  #
  # This 1) adds the song title/artist text overlay to each song,
  # 2) uses the song start and end times to specify how long each overlay should show.,
  # 3) adds labels to each overlay and uses previous overlay labels to start the next overlay
  # Example output: -filter_complex [1:0][2:0]concat=n=2:v=0:a=1[aud],[0:v][3:v]overlay=W*0.036:H*0.59:enable='between(t,0,146.7820)'[temp0],[temp0]drawtext=fontfile=/Library/Fonts/Helvetica-Bold.ttf:fontcolor=white:fontsize=120:x=w*.035:y=h*.95-text_h:line_spacing=25:textfile=temp/tempSongTextFile-1.txt:enable='between(t,0,146.7820)'[temp1],[temp1][4:v]overlay=W*0.036:H*0.59:enable='between(t,146.7820,269.6359)'[temp2],[temp2]drawtext=fontfile=/Library/Fonts/Helvetica-Bold.ttf:fontcolor=white:fontsize=120:x=w*.035:y=h*.95-text_h:line_spacing=25:textfile=temp/tempSongTextFile-2.txt:enable='between(t,146.7820,269.6359)'
  #
  # @param  {Integer} number of songs to be added to video
  # @return {String} ffmpeg filter argument string
  #####################################################
  def get_filter_str(num_songs,start_points,end_points,temp_folder,temp_song_text_base_filename,album_art_coordinates,
                     font_filepath,font_color,font_size,text_coordinates,text_line_spacing)
    filter_str = '-filter_complex '
    (1..num_songs).each do |i|                        # audio filter - concat all the songs. create [aud] out label
      filter_str+="[#{i}:0]"
    end
    filter_str += "concat=n=#{num_songs}:v=0:a=1[aud],"

    temp_num=0                                            # tempNum is a counter for the [tempx] output labels for the overlays
    (1..num_songs).each do |i|                        # loop through all songs
      image_num = num_songs+i                             # get image num (there are the same number of songs as there are song album art images, so image num is sum of number of songs and this song number)
      i_minus_1 = i-1                                     # go from one-based song number to zero based arrays that store song info
      first_start_point = "#{start_points[i_minus_1]}"   # get song start point (seconds from beginning of vid)
      first_start_point = sprintf('%.4f',first_start_point)
      first_end_point = "#{end_points[i_minus_1]}"       # get song end point (seconds from beginning of vid)
      first_end_point = sprintf('%.4f',first_end_point)
      temp_text_file="#{temp_folder}/#{temp_song_text_base_filename}-#{i}.txt"

      if i == 1
        filter_str += "[0:v]"                              # if the first song, use the inital video stream as input
      else
        filter_str += "[temp#{temp_num}]"                   # if not first song, use the temp output label created in previous iteration
        temp_num = temp_num+1                              # increment the tempNum counter for next temp label
      end
      filter_str += "[#{image_num}:v]overlay=#{album_art_coordinates}:enable='between(t,#{first_start_point},#{first_end_point})'[temp#{temp_num}],"  # sets the image art coordinates, the start/end time to show the image and outputs the [tempx] label
      filter_str += "[temp#{temp_num}]"                     # use the [tempx] label from the image art as input
      temp_num = temp_num+1                                 # increment the tempNum counter for next temp label
      filter_str += "drawtext=fontfile=#{font_filepath}:fontcolor=#{font_color}:fontsize=#{font_size}:#{text_coordinates}:line_spacing=#{text_line_spacing}:textfile=#{temp_text_file}:enable='between(t,#{first_start_point},#{first_end_point})'"   # place the song title and song artist text and set the start and end times to show the text
      if i != num_songs
        filter_str+="[temp#{temp_num}],"                     # if not the last song, then set the out label and use a comma so next filter can start
      end
    end
    check_post_conds(filter_str => 'var_exists')
    filter_str
  end

  #####################################################
  # Get ffmpeg output argument string
  #
  # This generates the last part of the ffmpeg command, the output file argument.
  # -map [aud] maps the concatenated audio files to the output file
  # -preset ultrafast sets the quality to low and the render time to fast (it is actually still quite a high quality)
  # -y automatically says yes to any questions ffmpeg asks
  # -loglevel quiet makes ffmpeg log almost nothing to the console
  # the .mp4 file at the end of the line is the final rendered video file
  # example output: -map [aud] -preset ultrafast -y -loglevel quiet output/stream-4-mins-0613211648.mp4
  #
  # @param   {String} output mp4 path/filename
  # @return  {String} ffmpeg output argument string
  #####################################################
  def get_output_file_str(quality, output_path_and_filename, temp_folder)
    check_args(
      quality => 'var_exists,is_string,length_gte_1',
      output_path_and_filename => 'var_exists,is_string,length_lte_30',
      temp_folder => 'var_exists,is_string,length_gte_1'
    )
    output_str = " -map [aud] -preset #{quality} -y -loglevel quiet #{output_path_and_filename} -progress #{temp_folder}/ffmpeg-progress.log"
    check_post_conds(output_str => 'var_exists,is_string,length_gte_75') #75 chars would be: -map [aud] -preset x -y -loglevel quiet x -progress x/ffmpeg-progress.log
    output_str
  end

  #####################################################
  # Get total number of frames the output mp4 file will have
  #
  # This can be run right after ffmpeg starts - the ffmpeg output
  # file is generated early and contains the total frame number,
  # even before those frames have actually been generated.
  #
  # @param   {String} output mp4 path/filename
  # @return  {Integer} number of total frames of mp4 file
  #####################################################
  def get_num_frames_total(output_filepath)
    check_args(output_filepath => 'var_exists,is_string,length_gte_7') # 7 chars would be: x/x.mp4
    num_frames = ffprobe_frame_count(output_filepath)
    check_post_conds(num_frames => 'var_exists, is_number, gte_1')
    num_frames
  end

  #####################################################
  # Deletes temp files
  #
  # As clean up after video is generated, this function deletes the temp
  # album art and title/song text files that are in a temp folder.
  #
  # @param  {String} full path to and including temp folder
  # @return none
  #####################################################
  def delete_temp_files(temp_folder)
    temp_folder = temp_folder + '/'
    check_args(temp_folder => 'folder_exists')
    Dir.glob("#{temp_folder}/*.*").each { |file| File.delete(file)}  # delete all files in temp folder
    files=Dir[File.join("#{temp_folder}", '**', '*')]
    num_files=files.count { |file| File.file?(file) }
    check_post_conds(num_files => 'gte_0')
  end

  #####################################################
  # Deletes output files less than one minute
  #
  # Deletes any output files created during prior test runs
  # Test output files have stream-0-mins in filename
  #
  # @param  {String} full path to and including output folder
  # @return none
  #####################################################
  def delete_test_output_files(output_folder)
    check_args(output_folder => 'folder_exists')
    Dir.glob("#{output_folder}/stream-0-mins*").each { |file| File.delete(file)}
    files=Dir[File.join("#{output_folder}", '**', '*')]
    num_files=files.count { |file| File.file?(file) }
    check_post_conds(num_files => 'gte_0')
  end

  #####################################################
  # Safe way to run a terminal command in Ruby
  #
  # Takes command, turns it into an array using a space as the delimeter,
  # uses the array elements as arguments to Open3.capture3 in order
  # to get stdout, stderr and status.
  # If not successful, raises an exception, otherwise returns stdout
  # with trailing newline character removed
  # (This is a modified version of syscall function from
  # https://stackoverflow.com/posts/20001569/revisions), accessed 6/23/21
  #
  # @param    {String} terminal command
  # @return   {String} output (stdout) of the terminal command
  #####################################################
  def safe_sys_call(cmd)
    cmd_arr = cmd.split(" ")
    stdout, stderr, status = Open3.capture3(*cmd_arr)
    if status.exitstatus != 0
      raise "safe_sys_call command failed: #{stderr}"
    end
    stdout_newline_removed=stdout.slice!(0..-(1 + $/.size))   # remove trailing newline char
    stdout_newline_removed
  end

  #####################################################
  # Runs system call and only returns first line
  #
  # Safe terminal command using Open3,
  # only returns first line of stdout output
  #
  # @param    {String} terminal command
  # @return   {String} first line of output (stdout) from terminal command
  #####################################################
  def safe_sys_call_first_line(cmd)
    multi_line_output=safe_sys_call(cmd)
    first_line=multi_line_output.lines.first
    first_line_newline_removed=first_line.slice!(0..-(1 + $/.size))   # remove trailing newline char
    first_line_newline_removed
  end

  #####################################################
  # Runs ffprobe to get song length
  #
  # Safe ffprobe call using Open3 that gets song length
  # in seconds with four decimal places
  #
  # @param    {String} full path to and including song mp3 filename
  # @return   {Number} song length in seconds with four decimal places
  #####################################################
  def ffprobe_length_call(song_path)
    cmd="ffprobe -show_entries stream=duration -of compact=p=0:nk=1 -v fatal #{song_path}"
    song_length_str=safe_sys_call_first_line(cmd)
    song_length=song_length_str.to_f
    song_length_four_decimal_points=song_length.round(4)
    song_length_four_decimal_points
  end

  #####################################################
  # Runs ffprobe to get song title
  #
  # Safe ffprobe call using Open3 that gets song title
  # TODO: I'm unsure how well this is handling titles with special chars in them
  #
  # @param    {String} full path to and including song mp3 filename
  # @return   {String} song title (all lowercase)
  #####################################################
  def ffprobe_title_call(song_path)
    cmd="ffprobe -v error -show_entries format_tags=title -of default=nw=1:nk=1 #{song_path}"
    song_title=safe_sys_call(cmd)
    song_title
  end

  #####################################################
  # Runs ffprobe to get song artist name
  #
  # Safe ffprobe call using Open3 that gets song artist
  # TODO: I'm unsure how well this is handling artist names with special chars in them
  #
  # @param    {String} full path to and including song mp3 filename
  # @return   {String} song artist name (all lowercase)
  #####################################################
  def ffprobe_artist_call(song_path)
    cmd="ffprobe -v error -show_entries format_tags=artist -of default=nw=1:nk=1 #{song_path}"
    artist=safe_sys_call(cmd)
    artist
  end

  #####################################################
  # Runs ffprobe to get total frame count
  #
  # Safe ffprobe call using Open3 that gets frame count
  #
  # @param    {String} full path to and including video mp4 filename
  # @return   {Integer} total frame count in mp4 to be outputted
  #####################################################
  def ffprobe_frame_count(output_filepath)
    check_args(output_filepath => 'var_exists,is_string,length_gte_7')
    cmd = "ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 #{output_filepath}"
    num_frames = safe_sys_call(cmd)
    num_frames = num_frames.to_i
    check_post_conds(num_frames => 'var_exists, is_number, gte_1')
    num_frames
  end

  #####################################################
  # Check method arguments are correct and raise exceptions if not
  #
  # The conditions have custom syntax:
  #   is_string - checks if argument is a string
  #
  # @param    {Hash} Hash with keys/values for argument/desired-condition
  # @return   {String} song artist name (all lowercase)
  #####################################################

  def check_args(arg_conditions)
    check_conditions(arg_conditions)
  end

  def check_post_conds(var_conds)
    check_conditions(var_conds)
  end

  def check_conditions(var_conds)
    var_conds.each do |var, cond|
      cond_arr = cond.split(',')
      if cond_arr.length == 1
        check_condition(var,cond)
      else
        cond_arr.each do |this_cond|
          check_condition(var,this_cond)
        end
      end
    end
  end

  def check_condition(var, cond)
    case cond
    when 'var_exists'
      if var == nil
        raise "variable is nil"
      end
    when 'file_exists'
      file_path=var
      if !File.file?(var)
        raise "#{file_path} does not exist"
      end
    when 'file_empty'
      file = var
      if !File.zero?(var)
        raise "#{file} not empty after pre-vid setup"
      end
    when 'is_string'
      if !var.is_a?(String)
        raise "Parameter #{var} is not a string"
      end
    when 'is_number'
      if !var.is_a?(Numeric)
        raise "var #{var} is not a number"
      end
    when 'if_exists_is_number'
      if var != nil && !var.is_a?(Numeric)
        raise "var #{var} is not a number"
      end
    when 'gte_0'
      if var < 0
        raise "var is less than zero"
      end
    when 'gte_1'
      if var < 1
        raise "var is less than one"
      end
    when 'ne_8'
      if var != 8
        raise "var is not equal to eight"
      end
    when 'is_boolean'
      if var != true && var != false
        raise "var is not boolean"
      end
    when 'is_array'
      if !var.kind_of?(Array)
        raise "var is not an array"
      end
    when 'length_gte_1'
      if var.length == 0
        raise "var/array length is zero"
      end
    when 'length_gte_7'
      if var.length < 7
        raise "var length is less than seven"
      end
    when 'length_gte_30'
      if var.length < 30
        raise "var length is less than than 30"
      end
    when 'length_gte_75'
      if var.length < 75
        raise "var length is less than 75"
      end
    when 'is_1_or_2'
      if var != 1 && var != 2
        raise "var must be a 1 or a 2, but is #{var}"
      end
    when 'not_newsline'
      if var == "\n"
        raise "var is just a newline character"
      end
    when 'not_empty_string'
      if var == ''
        raise "var is empty string"
      end
    when 'ends_in_mp3'
      if !var.end_with? ".mp3"
        raise "var #{var} doesn't end in .mp3"
      end
    when 'ends_in_mp4'
      if !var.end_with? ".mp4"
        raise "var #{var} doesn't end in .mp4"
      end
    when 'ends_in_png'
      if !var.end_with? ".png"
        raise "var #{var} doesn't end in .png"
      end
    when 'folder_empty'
      folder = var
      numFiles=Dir[File.join(folder, '**', '*')].count { |file| File.file?(file) }
      if numFiles != 0
        raise "folder #{folder} not empty"
      end
    when 'folder_exists'
      folder = var
      if !Dir.exist?("#{folder}")
        raise "folder #{folder} does not exist"
      end
    when 'no_files_of_pattern'
      path_and_pattern = var
      numFiles=Dir.glob(path_and_pattern).count { |file| File.file?(file) }
      if numFiles != 0
        raise "folder still has files matching pattern"
      end

    end
  end


end

sv = Squidvid.new

system "ffmpeg -i /Users/markmcdermott/Movies/youtube/normal/15-sec.mp4 -i /Users/markmcdermott/Desktop/misc/lofi/playlist-1/10k-ty-beat.mp3 -c copy -map 0:v:0 -map 1:a:0 -y -loglevel quiet #{sv.options[:outputFolder]}/stream-0-mins.mp4"