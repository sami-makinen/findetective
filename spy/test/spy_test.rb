require 'test_helper'

class Spy::Test < ActiveSupport::TestCase
  test "truth" do
    assert_kind_of Module, Spy
  end

  test "trie" do
    trie = Spy::Trie.new
    trie.insert('suomi')
    assert trie.contains?('suomi')
    assert ! trie.contains?('suo')
    assert ! trie.contains?('suomia')
  end

  
end
