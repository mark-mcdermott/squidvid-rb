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
    if song_num == nil || !song_num.is_a?(Numeric) || song_num < 0
      raise ArgumentError.new("song_num param is nil or is not a number or less than zero")
    end
    this_start_point=0
    (0..song_num - 1).each do |j|
      this_start_point = this_start_point + this_lengths[j]
    end
    if this_start_point == nil || !this_start_point.is_a?(Numeric) || this_start_point < 0
      raise "start point is nil, not a number or less than zero"
    end
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
    if start_point == nil || !start_point.is_a?(Numeric) || start_point < 0
      raise ArgumentError.new("start_point param is nil or is not a number or less than zero")
    end
    if song_length == nil || !song_length.is_a?(Numeric) || song_length < 0
      raise ArgumentError.new("song_length param is nil or is not a number or less than zero")
    end
    this_end_point = start_point + song_length
    if this_end_point == nil || !this_end_point.is_a?(Numeric) || this_end_point < 0
      raise "this_end_point param is nil or is not a number or less than zero"
    end
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
    if this_total_length == nil || !this_total_length.is_a?(Numeric) || this_total_length <= 0
      raise "this_total_length param is nil or is not a number or less than or equal to zero"
    end
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
    if total_length == nil || !total_length.is_a?(Numeric) || total_length < 0
          raise ArgumentError.new("total_length param is nil or is not a number or less than zero")
    end
    if output_base_filename == nil || !output_base_filename.is_a?(String) || output_base_filename.length == 0
      raise ArgumentError.new("output_base_filename is nil, not a string or is empty string")
    end
    if current_date_mmddyyhhmm == nil || !current_date_mmddyyhhmm.is_a?(String) || current_date_mmddyyhhmm.length != 10 || !/\A\d+\z/.match(current_date_mmddyyhhmm)
      raise ArgumentError.new("current_date_mmddyyhhmm is nil or not a string or is not 10 chars long or is not all numbers")
    end
    mins_long=total_length/60
    output_filename="#{output_base_filename}-#{mins_long}-mins-#{current_date_mmddyyhhmm}.mp4"
    if output_filename == nil || !output_filename.is_a?(String) || !output_filename.end_with?(".mp4")
      raise ArgumentError.new("output_filename param is nil or is not a string or doesn't end in .mp4")
    end
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
    if vid_skip_to_point == nil || !vid_skip_to_point.is_a?(String) || vid_skip_to_point.length != 8
      raise ArgumentError.new("vid_skip_to_point param is nil or is not a string or has length not equal to eight")
    end
    if total_length == nil || !total_length.is_a?(Numeric) || total_length < 0
      raise ArgumentError.new("total_length param is nil or is not a number or less than zero")
    end
    if vid_path == nil || !vid_path.is_a?(String) || vid_path.length == 0 || !vid_path.end_with?(".mp4")
      raise ArgumentError.new("vid_skip_to_point param is nil or is not a string or equal to zero or does not end in mp4")
    end
    vid_str="-ss #{vid_skip_to_point} -t #{total_length} -i #{vid_path}"
    if vid_str == nil || !vid_str.is_a?(String) || vid_str.length == 0 || !vid_str.end_with?(".mp4")
      raise "vid_str param is nil or is not a string or empty or does not end in mp4"
    end
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
    if num_songs == nil || !num_songs.is_a?(Numeric) || num_songs < 1
      raise ArgumentError.new("num_songs param is nil or is not a number or is less than one")
    end
    if song_dir == nil || !song_dir.is_a?(String)
      raise ArgumentError.new("song_dir param is nil or is not a string or doesn't end in .mp3")
    end
    if lengths == nil || !lengths.kind_of?(Array)
      raise ArgumentError.new("lengths param is nil or is not an array")
    end
    if songs == nil || !songs.kind_of?(Array)
      raise ArgumentError.new("songs param is nil or is not an array")
    end
    input_songs_str = ''
    (0..num_songs - 1).each do |i|
      if quick_test==true
        input_songs_str += "-t #{lengths[i]} -i #{song_dir}/#{songs[i]} "
      else
        input_songs_str += "-i #{song_dir}/#{songs[i]} "
      end
    end
    if input_songs_str == nil || !input_songs_str.is_a?(String) || input_songs_str.length < 1
      raise ArgumentError.new("input_songs_str param is nil or is not a string or has a length of less than one")
    end
    input_songs_str
  end

  #####################################################
  # Get images input argument string for ffmpeg command
  #
  # -i is the input images filepath/filename
  # Example output: -i dancer.jpg -i sunshine.jpg
  # See https://ffmpeg.org/ffmpeg.html#toc-Description for ffmpeg input file option details
  #
  # @return {String} ffmpeg images input argument string
  #####################################################
  # def get_images_str(temp_folder, images)
  #   input_images_str = ''
  #   (0..num_songs - 1).each do |i|
  #     input_images_str += "-i #{temp_folder}/#{images[i]} "
  #   end
  # end

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
    if !Dir.exist?("#{temp_folder}")
      raise "output_folder (#{temp_folder}) does not exist"
    end
    Dir.glob("#{temp_folder}/*.*").each { |file| File.delete(file)}  # delete all files in temp folder
    files=Dir[File.join("#{temp_folder}", '**', '*')]
    num_files=files.count { |file| File.file?(file) }
    if num_files != 0
      raise "temp_folder not empty after running delete_temp_files"
    end
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
    if !Dir.exist?(output_folder)
      raise "output_folder (#{output_folder}) does not exist"
    end
    Dir.glob("#{output_folder}/stream-0-mins*").each { |file| File.delete(file)}
    files=Dir[File.join("#{output_folder}", '**', '*')]
    numFiles=files.count { |file| File.file?(file) }
    if numFiles != 0
      raise "output_folder not empty after running delete_temp_files"
    end
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
  # TODO: I'm unsure how well this is handling titles with special chars in them
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
        raise "var #{var} is less than zero"
      end
    when 'is_boolean'
      if var != true && var != false
        raise "var #{var} is not boolean"
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
        raise "folder still has files matching patternchec"
      end

    end
  end


end

sv = Squidvid.new

system "ffmpeg -i /Users/markmcdermott/Movies/youtube/normal/15-sec.mp4 -i /Users/markmcdermott/Desktop/misc/lofi/playlist-1/10k-ty-beat.mp3 -c copy -map 0:v:0 -map 1:a:0 -y -loglevel quiet #{sv.options[:outputFolder]}/stream-0-mins.mp4"