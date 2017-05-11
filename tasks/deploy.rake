require 'yaml'
require File.join(File.dirname(__FILE__), 'deploy.rb')

# CONFIGURATION

set :envs, ->{ %i(vagrant production) }
set :env, ->{ ENV['DEPLOY_ENV'] }

set :config, ->{ YAML.load_file('env.yml') }
set :server_name, ->{ fetch(:config)['server_name'] }

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
  deploy_task app: %i(env) do
    docker_build name: 'app', path: '/vagrant/images/app', build_args: { BIOSENTIERS_BACKEND_REF: 'deploy', TIME: Time.now.to_i.to_s }
  end

  deploy_task db: %i(env) do
    docker_build name: 'db', path: '/vagrant/images/db'
  end

  deploy_task rp: %i(env) do
    docker_build name: 'rp', path: '/vagrant/images/rp'
  end
end

deploy_task build: %i(build:app build:db build:rp)

deploy_task cleanup: %i(env) do

  unused_ids = capture(:docker, :images).strip.split(/\n+/)
    .select{ |line| line.match(/^<none>/) || (line.match(/^127.0.0.1/) && line.match(/<none>/)) }
    .collect{ |line| line.split(/\s+/)[2] }

  if unused_ids.none?
    puts "No images to clean up"
  else
    execute :docker, :rmi, unused_ids.join(' ')
  end
end

namespace :deploy do
  deploy_task stack: %i(env) do
    with APP_TAG: 'deploy' do
      docker_stack_deploy name: 'biosentiers', compose_file: '/vagrant/roles/biosentiers/templates/docker-compose.yml'
    end
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

fetch(:envs).each do |env|
  task env do
    ENV['DEPLOY_ENV'] = env.to_s
  end
end

deploy_task uname: %i(env) do
  puts capture(:uname, '-a')
end

task :env do
  envs = fetch(:envs).collect &:to_s
  deploy_env = ENV['DEPLOY_ENV']
  raise "$DEPLOY_ENV must be set; use `rake <env> <task>` with env being one of #{envs.join(', ')}" unless deploy_env
  raise "Unsupported deployment environment #{deploy_env}; supported environments are #{envs.join(', ')}" unless envs.include? deploy_env

  #Dotenv.load! ".env.#{deploy_env}"
  ENV['DEPLOY_ENV'] = deploy_env
end

def docker_build name:, path:, registry: '127.0.0.1:5000', tag: 'latest', build_args: {}, push: true

  name_and_tag = "#{registry}/#{name}:#{tag}"

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
