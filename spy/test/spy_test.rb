require 'test_helper'

class Spy::Test < ActiveSupport::TestCase
  test "truth" do
    assert_kind_of Module, Spy
  end
end
