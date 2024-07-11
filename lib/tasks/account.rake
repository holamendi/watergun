namespace :account do
  desc "set up a new account"
  task :setup, [:hostname, :public_ip, :cpu_type, :email] => :environment do |_, args|
    hostname = args[:hostname]
    public_ip = args[:public_ip]
    cpu_type = args[:cpu_type]
    email = args[:email]

    if hostname.blank? || public_ip.blank? || cpu_type.blank?
      puts "Usage: rake server:create[hostname,public_ip,cpu_type]"
      exit 1
    end

    if Account.any?
      puts "An account already exists"
      exit 1
    end

    account = Account.create!(name: "default")
    server = account.servers.create!(name: hostname, public_ip:, cpu_type:)
    user = account.users.create!(email:, password: SecureRandom.hex(16))

    token = user.signed_id(expires_at: 1.day.from_now, purpose: :first_run)
    public_key = server.ssh_key.public_key
    response = {token:, public_key:}

    puts "ACCOUNT_DATA:#{response.to_json}"
  end
end
