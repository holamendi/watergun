return unless Rails.env.development?

Rails.application.console do
  def login
    puts "Setting current session"
    Current.session = Session.last
  end

  login
end
