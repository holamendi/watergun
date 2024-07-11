namespace :account do
  desc "set up a new account"
  task setup: :environment do |_, args|
    hostname, public_ip, cpu_type, email = ARGV[1..]

    if hostname.blank? || public_ip.blank? || cpu_type.blank?
      puts "Usage: rake account:setup <hostname> <public_ip> <cpu_type> <email>"
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
