namespace :account do
  desc "set up a new account"
  task :setup, [:hostname, :public_ip, :cpu_type] => :environment do |_, args|
    hostname = args[:hostname]
    public_ip = args[:public_ip]
    cpu_type = args[:cpu_type]

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

    data = {
      first_signup_token: account.first_signup_token,
      public_key: server.ssh_key.public_key
    }

    puts "ACCOUNT_DATA:#{data.to_json}"
  end
end
