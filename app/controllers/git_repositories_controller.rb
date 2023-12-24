class GitRepositoriesController < ApplicationController
  def index
    render partial: "git_repositories/select"
  end
end
