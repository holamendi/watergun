class Api::Internal::SetupsController < ActionController::API
  def create
    unless setup_token_is_valid?
      return render json: {error: "Invalid setup token"}, status: :unauthorized
    end

    if Account.any?
      return render json: {error: "An account already exists"}, status: :unprocessable_content
    end

    begin
      ApplicationRecord.transaction do
        create_account!
        create_server!
        create_user!
      end
    rescue => e
      return render json: {error: e.message}, status: :unprocessable_content
    end

    render json: {
      first_run_url: pretty_first_run_url(signed_id: first_run_token),
      public_key: server.ssh_key.public_key
    }
  end

  private

  def bearer_token
    ActionController::HttpAuthentication::Token.token_and_options(request).first
  end

  def setup_token_is_valid?
    setup_token.present? && ActiveSupport::SecurityUtils.secure_compare(setup_token, bearer_token)
  end

  def create_account!
    @account = Account.create!(name: "Default")
  end

  def create_server!
    @server = @account.servers.create!(server_params)
  end

  def create_user!
    @user = User.create!(user_params.merge(password: SecureRandom.alphanumeric(16)))
    @user.memberships.create!(account: @account)
  end

  def first_run_token
    @user.signed_id(purpose: :first_run)
  end

  def setup_token
    ENV.fetch("ACCOUNT_SETUP_TOKEN").presence
  end

  def server_params
    params.require(:server).permit(:name, :public_ip, :cpu_type)
  end

  def user_params
    params.require(:user).permit(:email)
  end
end
