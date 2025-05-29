require "test_helper"

class TrackedSymbolsControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get tracked_symbols_create_url
    assert_response :success
  end

  test "should get destroy" do
    get tracked_symbols_destroy_url
    assert_response :success
  end
end
