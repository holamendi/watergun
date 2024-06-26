class RenameOrgsToAccounts < ActiveRecord::Migration[7.1]
  def change
    rename_table :orgs, :accounts

    # Update foreign keys
    rename_column :api_tokens, :org_id, :account_id
    rename_column :apps, :org_id, :account_id
    rename_column :command_runs, :org_id, :account_id
    rename_column :container_checks, :org_id, :account_id
    rename_column :containers, :org_id, :account_id
    rename_column :deployments, :org_id, :account_id
    rename_column :domains, :org_id, :account_id
    rename_column :env_variables, :org_id, :account_id
    rename_column :github_access_tokens, :org_id, :account_id
    rename_column :github_repos, :org_id, :account_id
    rename_column :memberships, :org_id, :account_id
    rename_column :projects, :org_id, :account_id
    rename_column :server_action_logs, :org_id, :account_id
    rename_column :server_actions, :org_id, :account_id
    rename_column :servers, :org_id, :account_id
    rename_column :service_links, :org_id, :account_id
    rename_column :services, :org_id, :account_id
    rename_column :ssh_keys, :org_id, :account_id

    # Update indexes
    rename_index :api_tokens, "index_api_tokens_on_org_id", "index_api_tokens_on_account_id"
    rename_index :apps, "index_apps_on_org_id", "index_apps_on_account_id"
    rename_index :command_runs, "index_command_runs_on_org_id", "index_command_runs_on_account_id"
    rename_index :container_checks, "index_container_checks_on_org_id", "index_container_checks_on_account_id"
    rename_index :containers, "index_containers_on_org_id", "index_containers_on_account_id"
    rename_index :deployments, "index_deployments_on_org_id", "index_deployments_on_account_id"
    rename_index :domains, "index_domains_on_org_id", "index_domains_on_account_id"
    rename_index :env_variables, "index_env_variables_on_org_id", "index_env_variables_on_account_id"
    rename_index :github_access_tokens, "index_github_access_tokens_on_org_id", "index_github_access_tokens_on_account_id"
    rename_index :github_repos, "index_github_repos_on_org_id", "index_github_repos_on_account_id"
    rename_index :memberships, "index_memberships_on_org_id", "index_memberships_on_account_id"
    rename_index :memberships, "index_memberships_on_user_id_and_org_id", "index_memberships_on_user_id_and_account_id"
    rename_index :projects, "index_projects_on_org_id", "index_projects_on_account_id"
    rename_index :server_action_logs, "index_server_action_logs_on_org_id", "index_server_action_logs_on_account_id"
    rename_index :server_actions, "index_server_actions_on_org_id", "index_server_actions_on_account_id"
    rename_index :servers, "index_servers_on_org_id", "index_servers_on_account_id"
    rename_index :service_links, "index_service_links_on_org_id", "index_service_links_on_account_id"
    rename_index :services, "index_services_on_org_id", "index_services_on_account_id"
    rename_index :ssh_keys, "index_ssh_keys_on_org_id", "index_ssh_keys_on_account_id"

    # tables_with_fk = %w[api_tokens apps command_runs container_checks containers databases deployments domains env_variables github_access_tokens github_repos memberships projects server_action_logs server_actions servers service_links services ssh_keys]

    # tables_with_fk.each do |table|
    #   remove_foreign_key table, :orgs
    #   add_foreign_key table, :accounts
    # end
  end
end
