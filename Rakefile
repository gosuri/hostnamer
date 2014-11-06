require 'bundler'
require 'hostnamer/hostnamer'
require 'bundler/gem_tasks'
require 'dotenv/tasks'

$version = Hostnamer::VERSION
$profile = ENV['PROFILE'] || 'default'

ENV['S3_BUCKET'] ||= 'demandbase-pkgs'

desc 'Package .deb, .gem files under pkg'
task 'package'  do
  if `vagrant status | grep running`.strip == '' 
    # start if its not up
    system "vagrant up --provision"
  else
    system "vagrant provision"
  end
end

desc "Create tag v#{$version}, push pkg/* to #{ENV['S3_BUCKET']} s3 bucket"
task 'publish' => [:dotenv, :package] do
  profile = ENV['PROFILE'] || 'default'
  if `git tag | grep #{Hostnamer::VERSION}`.strip == ''
    `git tag v#{$version} && git push --tags`
  end
  `aws s3 cp pkg/hostnamer_#{$version}_all.deb s3://#{ENV['S3_BUCKET']}/ --profile #{profile}`
  `aws s3 cp pkg/hostnamer-#{$version}.gem s3://#{ENV['S3_BUCKET']}/ --profile #{profile}`
end
