base_dir = File.expand_path(File.join(File.dirname(__FILE__), ".."))
lib_dir  = File.join(base_dir, "lib")
test_dir = File.join(base_dir, "test")
# puts base_dir
# puts lib_dir
# puts test_dir

$LOAD_PATH.unshift(lib_dir)

require 'test/unit'

exit Test::Unit::AutoRunner.run(true, test_dir)