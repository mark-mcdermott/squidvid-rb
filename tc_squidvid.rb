require_relative "squidvid"
require "test/unit"

class TestSquidvid < Test::Unit::TestCase

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
    assert_not_equal('',song1,"Song is empty")
    assert_not_equal('',song2,"Song is empty")
    assert_match(/^.*\.mp3/, song1, "Song "+ song1 + " is not an mp3 file" )
    assert_match(/^.*\.mp3/, song2, "Song "+ song2 + " is not an mp3 file" )
  end

  def test_delete_temp_files
    tempFolder=temp
    Squidvid.new.delete_temp_files(tempFolder)
    numFiles=Dir[File.join(tempFolder, '**', '*')].count { |file| File.file?(file) }
    assert_equal(0, numFiles, "Temp folder not empty after running test_delete_temp_files")
  end

end
