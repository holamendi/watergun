class Accounts::SettingsController < ApplicationController
  def show
    Github::Integration.find_or_create_by!(account: current_account)
  end
end
