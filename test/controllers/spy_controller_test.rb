require 'test_helper'

class SpyControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get spy_index_url
    assert_response :success
  end

end
