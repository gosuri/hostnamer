# Introduction

Hostnamer is a cluster member discovery and registration tool for Route 53. It discovers other cluster members using an incremental DNS search and self registers with a unique identifier.

## Usage

```
$ hostnamer -n adops -t prod,virginia -Z XYZ
# adops-prod-virginia-00

$ hostnamer --help

Usage: hostnamer [options]
    -Z, --zone-id ZONEID             Route 53 zone id
    -n, --cluster-name [NAME]        Name of the cluster. Defaults to first chef role found under /etc/chef/node.json
    -j, --json-attributes [PATH]     Chef json attributes file. Defaults to /etc/chef/node.json
    -t, --tags [TAG,TAG]             Tags to postpend, eg: --tags production,california
    -p, --profile [PROFILE]          AWS user profile. Uses the current IAM or the default profile located under ~/.aws
    -r, --retries [RETRIES]          Number of times to retry before failing. Defaults to 5``:wq
    -w, --retry-wait SECONDS         Retry wait time. Defaults to 10s
    -v, --[no-]verbose               Run verbosely
        --version                    Show version
```

## Installation

### Ubuntu/Debian

```
version=1.0.2
wget https://s3.amazonaws.com/demandbase-pkgs-public/hostnamer_${version}_all.deb
sudo dpkg --install hostnamer_${version}_all.deb
sudo apt-get update -y && apt-get -f install # install any missing dependencies
```

### RubyGem

```
gem install hostnamer
```

## Development

### Publishing

```
$ rake package # packages .deb and .gem
$ rake publish # publishes to s3
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
