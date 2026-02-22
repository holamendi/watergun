# Create the default dev account, user, and membership.
# Idempotent — safe to run multiple times.
#
# After seeding, bin/local-dokku setup can find Account.first
# and create the local server record automatically.

account = Account.find_or_create_by!(name: "Default")

user = User.find_or_initialize_by(email: "hola@mendi.cl")
user.update!(name: "Dev User", password: "abc123")

Membership.find_or_create_by!(user: user, account: account)

puts "Seeded: account=#{account.name}, user=#{user.email}"
