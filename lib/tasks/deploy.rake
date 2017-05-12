require 'highline'
require 'paint'
require 'yaml'
require File.join(File.dirname(__FILE__), '..', 'deploy.rb')

# CONFIGURATION

set :envs, ->{ %i(vagrant production) }
set :env, ->{ ENV['DEPLOY_ENV'] }

set :config do
  config_files = [ 'env.yml', "env.#{fetch(:env)}.yml" ]
  config_files.inject({}) do |memo,file|
    memo.merge! YAML.load_file(file) if File.exist? file
    memo
  end
end

set :server_name, 'biosentiers'
set :src_dir, ->{ "/srv/#{fetch(:server_name)}" }
set :db_src_dir, ->{ "#{fetch(:src_dir)}/db" }
set :rp_src_dir, ->{ "#{fetch(:src_dir)}/rp" }
set :timestamp, ->{ Time.now.strftime("%Y%m%d%H%M%S") }
set :www_data_volume, ->{ "#{fetch(:server_name)}_www_data" }
set :registry, '127.0.0.1:5000'

set :default_ref, 'deploy'
%i(backend frontend).each do |type|
  set "#{type}_default_ref", ->{ fetch(:default_ref) }
  set "#{type}_repo", ->{ "#{fetch(:src_dir)}/#{type}" }
end

set :host do
  if ENV['DEPLOY_SSH_HOST']
    host = ENV['DEPLOY_SSH_HOST']
    host = "#{ENV['DEPLOY_SSH_USER']}@#{host}" if ENV['DEPLOY_SSH_USER']
    host = "#{host}:#{ENV['DEPLOY_SSH_PORT']}" if ENV['DEPLOY_SSH_PORT']
    host
  else
    ssh_config = vagrant_ssh_config
    "root@#{ssh_config['HostName']}:#{ssh_config['Port']}"
  end
end

# TASKS

namespace :build do
  %i(backend frontend).each do |type|
    deploy_task type => [ :env, "#{type}:checkout" ] do
      docker_build name: type, path: fetch("#{type}_checkout"), tag: fetch("#{type}_ref")
    end
  end

  deploy_task db: %i(env) do
    docker_build name: 'db', path: fetch(:db_src_dir)
  end

  deploy_task rp: %i(env) do
    docker_build name: 'rp', path: fetch(:rp_src_dir)
  end
end

deploy_task build: %i(build:app build:db build:rp)

deploy_task cleanup: %i(env tmp:clean_all) do

  unused_ids = capture(:docker, :images).strip.split(/\n+/)
    .select{ |line| line.match(/^<none>/) || (line.index(fetch(:registry)) == 0 && line.match(/<none>/)) }
    .collect{ |line| line.split(/\s+/)[2] }

  if unused_ids.none?
    puts "No images to clean up"
  else
    execute :docker, :rmi, unused_ids.join(' ')
  end
end

namespace :deploy do
  deploy_task frontend: %i(env) do
    execute :docker, 'run', '--rm', '--volume', "#{fetch(:www_data_volume)}:/var/www/dist", "#{fetch(:registry)}/#{fetch(:server_name)}/frontend:#{fetch(:frontend_ref)}"
  end

  deploy_task stack: %i(env) do
    with BACKEND_TAG: fetch(:backend_ref) do
      docker_stack_deploy name: fetch(:server_name), compose_file: "/etc/#{fetch(:server_name)}/docker-compose.yml"
    end
  end
end

deploy_task deploy: %i(env) do

  set :backend_ref, ask(%/Backend version to deploy (git commit, branch or tag; "none" to skip) [#{fetch(:backend_default_ref)}]: /, default: fetch(:backend_default_ref))
  set :frontend_ref, ask(%/Frontend version to deploy (git commit, branch or tag; "none" to skip) [#{fetch(:frontend_default_ref)}]: /, default: fetch(:frontend_default_ref))
  update_db = ask_boolean('Rebuild the database (yes/no) [no]: ')
  update_rp = ask_boolean('Rebuild the reverse proxy (yes/no) [no]: ')

  if !update_db && !update_rp && fetch(:backend_ref) == 'none' && fetch(:frontend_ref) == 'none'
    puts Paint['Nothing to deploy', :red]
    next
  end

  Rake::Task['build:db'].invoke if update_db
  Rake::Task['build:rp'].invoke if update_rp
  Rake::Task['build:backend'].invoke if fetch(:backend_ref) != 'none'

  if fetch(:frontend_ref) != 'none'
    Rake::Task['build:frontend'].invoke
    Rake::Task['deploy:frontend'].invoke
  end

  Rake::Task['deploy:stack'].invoke
end

task :env do
  envs = fetch(:envs).collect &:to_s
  deploy_env = ENV['DEPLOY_ENV']
  raise "$DEPLOY_ENV must be set; use `rake <env> <task>` with env being one of #{envs.join(', ')}" unless deploy_env
  raise "Unsupported deployment environment #{deploy_env}; supported environments are #{envs.join(', ')}" unless envs.include? deploy_env

  #Dotenv.load! ".env.#{deploy_env}"
  ENV['DEPLOY_ENV'] = deploy_env
end

fetch(:envs).each do |env|
  task env do
    ENV['DEPLOY_ENV'] = env.to_s
  end
end

deploy_task ps: %i(env) do

  puts

  containers = docker_ps.split /\n+/
  if containers.length <= 1
    puts "No containers are running"
  else
    containers.each do |container|
      puts container
    end
  end

  puts
end

%i(backend frontend).each do |type|
  namespace type do
    deploy_task checkout: [ "#{type}:update", :tmp ] do
      checkout_repo type: type.to_s, repo: fetch("#{type}_repo"), ref: fetch("#{type}_ref")
    end

    deploy_task update: %i(env) do
      within fetch("#{type}_repo") do
        execute :git, 'fetch', 'origin', '--tags', '+refs/heads/*:refs/heads/*'
      end
    end
  end
end

namespace :tmp do
  deploy_task clean: %i(env) do
    execute :rm, '-fr', fetch(:tmp)
  end

  deploy_task clean_all: %i(env) do
    execute :rm, '-fr', "/tmp/*-#{fetch(:server_name)}-*"
  end
end

deploy_task tmp: %i(env) do
  tmp_dir = capture :mktemp, '--suffix', "-#{fetch(:server_name)}-#{fetch(:timestamp)}", '-d'
  set :tmp, tmp_dir
end

deploy_task uname: %i(env) do
  puts capture(:uname, '-a')
end

def checkout_repo type:, repo:, ref:
  dir = "#{fetch(:tmp)}/#{type}"

  archive_file = "#{dir}/checkout.tar"
  checkout_dir = "#{dir}/checkout"

  execute :mkdir, '-p', checkout_dir

  within repo do
    execute :git, 'archive', '--output', archive_file, ref
  end

  execute :tar, '-C', checkout_dir, '-x', '--file', archive_file

  set "#{type}_checkout", checkout_dir
end

def docker_build name:, path:, registry: fetch(:registry), tag: 'latest', build_args: {}, push: true

  name_and_tag = "#{registry}/#{fetch(:server_name)}/#{name}:#{tag}"

  args = []
  args << '--tag' << name_and_tag

  build_args.each do |key,value|
    args << '--build-arg' << Shellwords.escape("#{key}=#{value}")
  end

  args << path

  execute :docker, 'build', *args
  execute :docker, 'push', name_and_tag
end

def docker_ps compose_project: nil, compose_service: nil, quiet: false, latest: false, status: nil

  ps_args = []
  ps_args << '--quiet' if quiet
  ps_args << '--latest' if latest
  ps_args << '--filter' << "label=com.docker.compose.project=#{compose_project}" if compose_project
  ps_args << '--filter' << "label=com.docker.compose.service=#{compose_service}" if compose_service
  ps_args << '--filter' << "status=#{status}" if status

  output = capture :docker, 'ps', *ps_args
  output.strip
end

def docker_stack_deploy name:, compose_file: nil

  args = []
  args << '--compose-file' << compose_file if compose_file
  args << name

  execute :docker, :stack, :deploy, *args
end
