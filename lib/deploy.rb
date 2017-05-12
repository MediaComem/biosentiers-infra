require 'fileutils'
require 'highline'
require 'shellwords'
require 'sshkit'
require 'sshkit/dsl'
require 'tmpdir'

include SSHKit::DSL
SSHKit.config.output_verbosity = :debug if ENV['DEBUG']

DEPLOY_DATA = {}

def set key, value = nil, &block
  DEPLOY_DATA[key.to_sym] = value.nil? && block ? block : value
end

def fetch key
  actual_key = key.to_sym
  if !DEPLOY_DATA.key?(actual_key)
    raise "Unknown deploy data key #{key.inspect}"
  elsif DEPLOY_DATA[actual_key].respond_to?(:call)
    DEPLOY_DATA[actual_key] = DEPLOY_DATA[actual_key].call
  else
    DEPLOY_DATA[actual_key]
  end
end

set :local_tmp, ->{ Dir.mktmpdir }

def deploy_cli
  @deploy_cli ||= HighLine.new
end

def ask question, default: nil, validate: ->(answer){ !answer.to_s.strip.empty? || default }
  next until validate.call(answer = deploy_cli.ask(question).to_s.strip)
  answer.empty? ? default : answer
end

def ask_boolean question, default: false
  answer = ask question, default: default, validate: ->(answer){ (answer.to_s.strip.empty? && !default.nil?) || answer.to_s.strip.match(/^(0|1|n|no|y|yes|f|false|t|true)$/i) }
  !answer.to_s.match(/^(1|y|yes|t|true)$/i).nil?
end

def deploy_task *args, &block
  task *args do |*task_args|
    on fetch(:host) do
      begin
        instance_exec *task_args, &block
      ensure
        tmp_dir = DEPLOY_DATA[:local_tmp]
        if !tmp_dir.respond_to?(:call)
          puts "Removing temporary directory #{tmp_dir}" if ENV['DEBUG']
          FileUtils.remove_entry_secure tmp_dir
          set :local_tmp, ->{ Dir.mktmpdir }
        end
      end
    end
  end
end

def vagrant_ssh_config
  FileUtils.mkdir_p 'tmp'

  config_file = File.join 'tmp', "vagrant-ssh-config-#{Time.now.strftime('%Y-%m-%d')}"
  unless File.exist? config_file
    File.open(config_file, 'w'){ |f| f.write `vagrant ssh-config`.strip }
  end

  Dir.glob(File.join('tmp', 'vagrant-ssh-config-*')).reject{ |f| f == config_file }.each do |file|
    FileUtils.remove_entry_secure file
  end

  File.read(config_file).split(/\n+/).reject(&:empty?).inject({}) do |memo,line|
    key, value = line.strip.split(/\s+/, 2)
    memo[key] = value
    memo
  end
end
