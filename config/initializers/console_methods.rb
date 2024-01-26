return unless Rails.env.development?

Rails.application.console do
  def set_current_session
    puts "Setting current session"
    Current.session = Session.last
  end

  set_current_session
end
