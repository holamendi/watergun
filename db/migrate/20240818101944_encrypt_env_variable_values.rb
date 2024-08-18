class EncryptEnvVariableValues < ActiveRecord::Migration[8.0]
  def change
    EnvVariable.find_each(&:encrypt)
  end
end
