require "test_helper"

module Accounts
  class ThemesControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in users(:bobby)
      @user = users(:bobby)
    end

    describe "#update" do
      test "updates the user theme" do
        patch account_theme_url, params: {user: {theme: "dark"}}

        assert_response :success
        assert_equal "dark", @user.reload.theme
      end

      test "updates with all valid themes" do
        User::THEMES.each do |theme|
          patch account_theme_url, params: {user: {theme: theme}}

          assert_response :success
          assert_equal theme, @user.reload.theme
        end
      end

      test "rejects invalid theme" do
        @user.update!(theme: "watergun")

        patch account_theme_url, params: {user: {theme: "invalid_theme"}}

        assert_response :unprocessable_content
        assert_equal "watergun", @user.reload.theme
      end

      test "returns turbo stream response" do
        patch account_theme_url, params: {user: {theme: "dracula"}}, as: :turbo_stream

        assert_response :success
        assert_match "turbo-stream", response.content_type
      end
    end
  end
end
