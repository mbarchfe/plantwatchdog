set :application, "solarlogger"
set :user, "solar"
set :repository,  "git@github.com:mbarchfe/solar-logger-server.git"

# If you aren't deploying to /u/apps/#{application} on the target
# servers (which is the default), you can specify the actual location
# via the :deploy_to variable:
set :deploy_to, "/home/solar/#{application}"

set :scm, :git
set :branch, "master"
set :deploy_via, :checkout
set :git_shallow_clone, 1

role :app, "78.47.21.53"
role :web, "78.47.21.53"
role :db,  "78.47.21.53", :primary => true

# set this because otherwise capistrano does not ask for a password when
# checking out from git on the server
default_run_options[:pty] = true 

task :after_update_code, :roles => :app do
  db_config = "#{shared_path}/config/app_config.yaml"
  run "cp #{db_config} #{release_path}/config"
end

namespace :deploy do
  task :start do
   # NOP
  end
  task :stop do
   # NOP
  end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end
