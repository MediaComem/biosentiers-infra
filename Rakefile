# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.
Dir.glob('lib/tasks/**/*.rake').each do |f|
  load File.join(File.dirname(__FILE__), f)
end
