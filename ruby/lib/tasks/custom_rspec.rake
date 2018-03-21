Rake::Task["spec"].clear

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = '--require spec_helper --color --format progress'
end
