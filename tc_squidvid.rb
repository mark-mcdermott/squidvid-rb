require_relative "squidvid"
require "test/unit"

class TestSquidvid < Test::Unit::TestCase
  class << self
    def startup
      #
    end
    def shutdown
      Squidvid.new().delete_temp_files('temp')
    end
  end

  def test_get_song_dir
    path="/Users/markmcdermott/Desktop/misc/lofi/playlist-"
    dir=Squidvid.new().get_song_dir(path)
    assert_not_nil(dir, "Song directory is nil" )
    assert_kind_of(String, dir, "Song directory not a string" )
    assert_not_equal('',dir,"Song directory is empty")
    assert_match(/hi[12]/, Squidvid.new().get_song_dir('hi'), "Song directory should be hi1 or hi2 if songBasePath is 'hi'" )
    assert_match(/[12]/, Squidvid.new().get_song_dir(''), "Song directory should be 1 or 2 if songBasePath is empty" )
    assert_match(/\/Users\/markmcdermott\/Desktop\/misc\/lofi\/playlist-[12]/, dir, "Song directory should be " + path + "1 or " + path + "2 but was " + dir )
  end

  def test_get_song_from_dir
    song1=Squidvid.new().get_song_from_dir('/Users/markmcdermott/Desktop/misc/lofi/playlist-1')
    song2=Squidvid.new().get_song_from_dir('/Users/markmcdermott/Desktop/misc/lofi/playlist-2')
    assert_not_nil(song1, "Song is nil" )
    assert_not_nil(song2, "Song is nil" )
    assert_kind_of(String,song1, "Song is not a string" )
    assert_kind_of(String,song2, "Song is not a string" )
    assert_not_equal('',song1,"Song string is empty")
    assert_not_equal('',song2,"Song string is empty")
    assert_match(/^.*\.mp3/, song1, "Song "+ song1 + " is not an mp3 file" )
    assert_match(/^.*\.mp3/, song2, "Song "+ song2 + " is not an mp3 file" )
  end

  def test_get_song
    song=Squidvid.new().get_song('/Users/markmcdermott/Desktop/misc/lofi/playlist-')
    assert_not_nil(song, "Song is nil" )
    assert_kind_of(String,song, "Song is not a string" )
    assert_not_equal('',song,"Song string is empty")
    assert_match(/^.*\.mp3/, song, "Song "+ song + " is not an mp3 file" )
  end

  def test_get_album_art_filename
    image_name=Squidvid.new().get_album_art_filename('dancer.mp3')
    assert_not_nil(image_name, "image_name is nil" )
    assert_kind_of(String,image_name, "image_name is not a string" )
    assert_not_equal('',image_name,"image_name string is empty")
    assert_match(/^.*\.png/, image_name, "image_name "+ image_name + " is not a png file" )
    # song=Squidvid.new().get_song('/Users/markmcdermott/Desktop/misc/lofi/playlist-')
    song_path='/Users/markmcdermott/Desktop/misc/lofi/playlist-1/10k-ty-beat.mp3'
    image_name=Squidvid.new().get_album_art_filename(song_path)
    assert_not_nil(image_name, "image_name is nil" )
    assert_kind_of(String,image_name, "image_name is not a string" )
    assert_not_equal('',image_name,"image_name string is empty")
    assert_match(/^.*\.png/, image_name, "image_name "+ image_name + " is not a png file" )
  end

  def test_get_album_art
    song_path='/Users/markmcdermott/Desktop/misc/lofi/playlist-1/10k-ty-beat.mp3'
    temp_folder="temp"
    image_filename=Squidvid.new().get_album_art(song_path,temp_folder)
    image_filepath="#{temp_folder}/#{image_filename}"
    assert_not_nil(image_filename, "image_filename is nil" )
    assert_kind_of(String,image_filename, "image_filename is not a string" )
    assert_not_equal('',image_filename,"image_filename string is empty")
    assert_match(/^.*\.png/, image_filename, "image_filename "+ image_filename + " is not a png file" )
    assert(File.file?("#{image_filepath}"), "image file #{image_filename} does not exist after trying to create it")
  end

  def test_get_length
    song_path='/Users/markmcdermott/Desktop/misc/lofi/playlist-1/10k-ty-beat.mp3'
    length=Squidvid.new().get_length(song_path)
    assert_not_nil(length, "length is nil" )
    assert_kind_of(Numeric,length, "length is not a number" )
    assert(length > 0, "length is less than or equal to zero")
  end

  def test_get_title
    song_path='/Users/markmcdermott/Desktop/misc/lofi/playlist-1/10k-ty-beat.mp3'
    title=Squidvid.new().get_title(song_path)
    assert_not_nil(title, "title is nil" )
    assert_kind_of(String,title, "title is not a string" )
    assert_not_equal('',title,"title is blank string")
    assert_equal('10k ty beat',title,"get_title is not getting correct title")
  end

  def test_get_artist
    song_path='/Users/markmcdermott/Desktop/misc/lofi/playlist-1/10k-ty-beat.mp3'
    artist=Squidvid.new().get_artist(song_path)
    assert_not_nil(artist, "artist is nil" )
    assert_kind_of(String,artist, "artist is not a string" )
    assert_not_equal('',artist,"artist is blank string")
    assert_equal('ntourage',artist,"get_artist is not getting correct artist name")
  end

  def test_get_song_text
    song_path='/Users/markmcdermott/Desktop/misc/lofi/playlist-1/10k-ty-beat.mp3'
    song_num=0
    temp_folder="temp"
    temp_son_text_base_filename="tempSongTextFile"
    sv=Squidvid.new()
    text=sv.get_song_text(song_path,song_num,temp_folder,temp_son_text_base_filename)
    assert_not_nil(text, "text is nil" )
    assert_kind_of(String,text, "text is not a string" )
    assert_not_equal('',text,"text is blank string")
    assert_equal("10k ty beat\nntourage",text,"text for temp text file is incorrect")
    sv.delete_temp_files(temp_folder)
  end

  def test_get_start_point
    song_num=1
    this_lengths=[60,60]
    start_point=Squidvid.new().get_start_point(song_num,this_lengths)
    assert_not_nil(start_point, "start_point is nil" )
    assert_kind_of(Numeric,start_point, "start_point is not a number" )
    assert_equal(60,start_point,"start point calculation is wrong")
  end

  def test_get_end_point
    start_point=60
    song_length=60
    end_point=Squidvid.new().get_end_point(start_point,song_length)
    assert_not_nil(end_point, "start_point is nil" )
    assert_kind_of(Numeric,end_point, "start_point is not a number" )
    assert_equal(120,end_point,"start point calculation is wrong")
  end

  def test_get_total_length
    end_points=[60,120,180]
    total_length=Squidvid.new().get_total_length(end_points)
    assert_not_nil(total_length, "total_length is nil" )
    assert_kind_of(Numeric,total_length, "total_length is not a number" )
    assert_equal(180,total_length,"total length calculation is wrong")
  end

  def test_get_output_filename
    total_length=240
    output_base_filename='stream'
    current_date_mmddyyhhmm='0623211537'
    output_filename=Squidvid.new().get_output_filename(total_length,output_base_filename,current_date_mmddyyhhmm)
    assert_not_nil(output_filename, "output_filename is nil" )
    assert_kind_of(String,output_filename, "output_filename is not a string" )
    assert_equal('stream-4-mins-0623211537.mp4',output_filename,"output_filename is incorrect")
  end

  def test_get_vid_str
    vid_skip_to_point='00:01:00'
    total_length=240
    vid_path='/Users/markmcdermott/Movies/youtube/long/beach-3-hr-skip-first-min.mp4'
    vid_str_actual=Squidvid.new().get_vid_str(vid_skip_to_point, total_length, vid_path)
    vid_str_expected="-ss 00:01:00 -t 240 -i /Users/markmcdermott/Movies/youtube/long/beach-3-hr-skip-first-min.mp4"
    assert_not_nil(vid_str_actual, "vid_str_actual is nil" )
    assert_kind_of(String,vid_str_actual, "vid_str_actual is not a string" )
    assert_equal(vid_str_expected,vid_str_actual,"vid_str_actual string is incorrect")
  end

  def test_get_songs_str
    num_songs=2
    i=1 #(song two)
    song_dir='/Users/markmcdermott/Desktop/misc/lofi/playlist-1'
    lengths=[60,60]
    songs=['dancer.mp3','test.mp3']
    song_str_actual=Squidvid.new().get_songs_str(num_songs, song_dir,lengths,songs)
    song_str_expected="-i /Users/markmcdermott/Desktop/misc/lofi/playlist-1/dancer.mp3 -i /Users/markmcdermott/Desktop/misc/lofi/playlist-1/test.mp3 "
    assert_not_nil(song_str_actual, "song_str_expected is nil" )
    assert_kind_of(String,song_str_actual, "song_str_expected is not a string" )
    assert_equal(song_str_expected,song_str_actual,"song_str_expected string is incorrect")
  end

  def test_delete_temp_files
    temp_folder="temp"
    Squidvid.new.delete_temp_files(temp_folder)
    files=Dir[File.join("#{temp_folder}", '**', '*')]
    num_files=files.count { |file| File.file?(file) }
    assert_equal(0, num_files, "Temp folder still has " + num_files.to_s + " file(s) after running test_delete_temp_files")
  end

  def test_delete_test_output_files
    outputFolder="output"
    Squidvid.new.delete_test_output_files(outputFolder)
    numFiles=Dir.glob("#{outputFolder}/stream-0-mins*").count { |file| File.file?(file) }
    assert_equal(0, numFiles, "Output folder still has " + numFiles.to_s + "file(s) starting with 'stream-0-mins' after running delete_test_output_files")
  end

  def test_pre_vid_setup
    tempFolder="temp"
    outputFolder="output"
    Squidvid.new.pre_vid_setup(tempFolder, outputFolder)
    tempFiles=Dir[File.join("#{tempFolder}", '**', '*')]
    numTempFiles=tempFiles.count { |file| File.file?(file) }
    assert_equal(1,numTempFiles, "TempFolder not empty after running delete_temp_files - " + numTempFiles.to_s + " file found " + tempFiles.to_s)
    numOutputTestFiles=Dir.glob("#{outputFolder}/stream-0-mins*").count { |file| File.file?(file) }
    assert_equal(0,numOutputTestFiles, "OutputFolder still has 'stream-0-mins' file(s) after running delete_temp_files")
    assert_true(File.file?("#{tempFolder}/ffmpeg-progress.log"), "ffmpeg-progress.log does not exist after trying to create it")
    assert_equal(0,File.size("#{tempFolder}/ffmpeg-progress.log"), "ffmpeg-progress.log not empty after pre-vid setup")
  end

  def test_safe_sys_call
    sv=Squidvid.new
    assert_equal("hi",sv.safe_sys_call("echo hi"), "Open3 system call not properly echoing 'hi'")
  end

  def test_safe_sys_call_first_line
    song_path='/Users/markmcdermott/Desktop/misc/lofi/playlist-1/10k-ty-beat.mp3'
    length=Squidvid.new.safe_sys_call_first_line("ffprobe -show_entries stream=duration -of compact=p=0:nk=1 -v fatal #{song_path}")
    assert_equal("91.637551",length, "Open3 ffprobe call not properly returning ntourage 10k-ty-beat.mp3 song length")
  end

  def test_ffprobe_length_call
    song_path='/Users/markmcdermott/Desktop/misc/lofi/playlist-1/10k-ty-beat.mp3'
    length=Squidvid.new.ffprobe_length_call(song_path)
    length_rounded=length.to_f.round(4)
    assert_equal(91.6376,length_rounded, "ffprobe_sys_call call not properly returning ntourage 10k-ty-beat.mp3 song length")
  end

  def test_ffprobe_title_call
    song_path='/Users/markmcdermott/Desktop/misc/lofi/playlist-1/10k-ty-beat.mp3'
    title=Squidvid.new().ffprobe_title_call(song_path)
    assert_not_nil(title, "title is nil" )
    assert_kind_of(String,title, "title is not a string" )
    assert_not_equal('',title,"title is blank string")
    assert_equal('10k ty beat',title,"test_ffprobe_title_call is not getting correct title")
  end

  def test_ffprobe_artist_call
    song_path='/Users/markmcdermott/Desktop/misc/lofi/playlist-1/10k-ty-beat.mp3'
    artist=Squidvid.new().ffprobe_artist_call(song_path)
    assert_not_nil(artist, "artist is nil" )
    assert_kind_of(String,artist, "artist is not a string" )
    assert_not_equal('',artist,"artist is blank string")
    assert_equal('ntourage',artist,"test_ffprobe_artist_call is not getting correct artist name")
  end

end
