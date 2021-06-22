require 'fileutils'

class Squidvid

  def initialize

    @options = {
      :num_songs => 2,
      :numSongs => 2,                            # set options
      :quickTest => true,
      :quickTestTotalLength => 14,               # seconds
      :songBasePath => '/Users/markmcdermott/Desktop/misc/lofi/playlist-',
      :fontFilepath => '/Library/Fonts/Helvetica-Bold.ttf',
      :vid => '/Users/markmcdermott/Movies/youtube/long/beach-3-hr-skip-first-min.mp4',
      :quality => 'ultrafast',
      :outputBaseFilename => 'stream',
      :albumArtCoordinates => 'W*0.036:H*0.59',    # W is screen width, w is image width (W/2-w/2:H/2-h/2 centers)
      :fontColor => 'white',
      :fontSize => 120,
      :textCoordinates => 'x=w*.035:y=h*.95-text_h',
      :textLineSpacing => 25,
      :tempFolder => 'temp',
      :tempSongTextBaseFilename => 'tempSongTextFile', #basename of temporary text file with song name and song artist (fullname will be like tempSongTextFile-1.txt)
      :outputFolder => 'output',
      :vidSkipToPoint => '0:01:00'               # means skip the first minute of the video (skips over the watermarked parts)
    }

    pre_vid_setup
    song_dir = get_song_dir(options[:songBasePath])

    (0..options[:num_songs] - 1).each do |i|
      song=get_song_from_dir(song_dir)
      puts song
    end



  end

  def options
    @options
  end


  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
  # Some necessary pre-vid setup
  #
  # Cleans up temp files in case program stopped early in the previous run.
  # Cleans up test output mp4 files.
  # Makes a blank line.
  # Creates progress.txt file for progress info.
  #
  # @params   none
  # @return   none
  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
  def pre_vid_setup
    delete_temp_files(options[:tempFolder])
    delete_test_output_files()
    puts ""
    FileUtils.touch("#{options[:tempFolder]}/ffmpeg-progress.log")
  end

  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
  # Randomly picks one of two mp3 directories
  #
  # This is obviously custom to my setup - you will want to change this most likely.
  # I have two mp3 playlist folders: playlist-1 and playlist-2.
  # Path returned does #not* have a trailing forward slash at the end.
  #
  # @param  {String} full path to song folder, but without number at end. ie, /Users/markmcdermott/Desktop/misc/lofi/playlist-
  # @return {String} full path. ie, /Users/markmcdermott/Desktop/misc/lofi/playlist-1
  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
  def get_song_dir(song_base_path)
    if song_base_path == nil || !song_base_path.is_a?(String)
      raise ArgumentError.new("song_base_path option (#{song_base_path}) is nil or is not a string")
    end
    randomNum = rand(2) + 1  # random value of 1 or 2
    if randomNum == nil || !randomNum.is_a?(Integer) || randomNum != 1 && randomNum != 2
      raise "random num for song directory must be a 1 or a 2, but is #{randomNum}"
    end
    fullPath="#{song_base_path}#{randomNum}"
    if fullPath == nil || !fullPath.is_a?(String) || fullPath == ''
      raise "fullPath var is nil, not a string or is blank"
    end
    fullPath
  end

  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
  # Randomly picks a mp3 file from a given mp3 folder
  #
  # Param path does not have trailing forward slash at end.
  #
  # @param  {String} path to mp3 folder. ie, /Users/markmcdermott/Desktop/misc/lofi/playlist-1
  # @return {String} mp3 filename with no path. ie, dancer.mp3
  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
  def get_song_from_dir(song_dir)
    if song_dir == nil || !song_dir.is_a?(String)
      raise ArgumentError.new("song_dir option (#{song_dir}) is nil or is not a string")
    end
    song=Dir.glob("#{song_dir}/*").sample
    if song == nil || !song.is_a?(String)
      raise "song (#{song}) is nil or is not a string"
    end
    if !song.end_with? ".mp3"
      raise "song (#{song}) is not an mp3 file"
    end
    song
  end

  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
  # Deletes temp files
  #
  # As clean up after video is generated, this function deletes the temp
  # album art and title/song text files that are in a temp folder.
  #
  # @para tempFolder - full path to and including temp folder
  # @return none
  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
  def delete_temp_files(tempFolder)
    if !Dir.exist?(tempFolder)
      raise "tempFolder (#{tempFolder}) does not exist"
    end
    Dir.glob(tempFolder).each { |file| File.delete(file)} # delete all files in temp folder
    numFiles=Dir[File.join(tempFolder, '**', '*')].count { |file| File.file?(file) }
    numFiles=Dir[File.join(tempFolder, '**', '*')].count { |file| print file }
    if numFiles != 0
      print numFiles
      raise "tempFolder not empty after running delete_temp_files"
    end
  end

  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
  # Deletes output files less than one minute
  #
  # Delets any output files created during prior test runs
  # Test output files have stream-0-mins in filename
  #
  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
  def delete_test_output_files(outputFolder)
    if !Dir.exist?('outputFolder')
      raise "outputFolder (#{outputFolder}) does not exist"
    end
    Dir.glob("#{outputFolder}/stream-0-mins*").each { |file| File.delete(file)}
    numFiles=Dir.glob("#{outputFolder}/stream-0-mins*").count { |file| File.file?(file) }
    if numFiles != 0
      raise "tempFolder not empty after running delete_temp_files"
    end
  end

end

sv = Squidvid.new

system "ffmpeg -i /Users/markmcdermott/Movies/youtube/normal/15-sec.mp4 -i /Users/markmcdermott/Desktop/misc/lofi/playlist-1/10k-ty-beat.mp3 -c copy -map 0:v:0 -map 1:a:0 -y -loglevel quiet #{sv.options[:outputFolder]}/stream-0-mins.mp4"