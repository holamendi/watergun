namespace :account do
  desc "set up a new account"
  task setup: :environment do |_, args|
    hostname, public_ip, cpu_type, domain, email = ARGV[1..]

    if hostname.blank? || public_ip.blank? || cpu_type.blank? || email.blank?
      puts "Usage: rake account:setup <hostname> <public_ip> <cpu_type> <domain> <email>"
      exit 1
    end

    if Account.any?
      puts "An account already exists"
      exit 1
    end

    account = Account.create!(name: "default")
    server = account.servers.create!(name: hostname, public_ip:, cpu_type:)

    Current.account = account
    Current.server = server

    user = account.users.create!(email:, password: SecureRandom.hex(16))
    project = account.projects.create!(name: "watergun", server:)
    app = project.apps.create!(name: "watergun", dokku_id: "watergun", status: :active, deployed_at: Time.current)
    app.domains.create!(hostname: domain, status: :active, is_default: true, ssl_enabled: true)
    app.create_github_repo!(account:, repo: "holamendi/watergun", branch: "main")

    token = user.signed_id(expires_in: 1.day, purpose: :first_run_v2)
    public_key = server.ssh_key.public_key
    response = {token:, public_key:}

    puts "ACCOUNT_DATA:#{response.to_json}"
  end
end
