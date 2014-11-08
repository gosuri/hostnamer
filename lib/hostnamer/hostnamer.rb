require 'socket'
require 'syslog'
require 'timeout'
require 'tempfile'
require 'optparse'

module Hostnamer
  module_function
  VERSION = "1.0.1"
  class DNSInsertFailed < RuntimeError; end
  class DNSQueryFailed  < RuntimeError; end

  def run(opts)
    log "run" do
      zoneid    = opts[:zone_id] or raise "zone id must be present, specify using --zone-id ZONEID"
      tags      = opts[:tags]         || []
      name      = opts[:cluster_name] || detect_first_chef_role(opts[:json_attrs]) || 'instance'
      retries   = opts[:retries]      || 5
      retrywait = opts[:retry_wait]   || 10
      profile   = opts[:profile]
      ip        = detect_ip
      tags.unshift(name)

      retrying(retries) do
        begin
          host, domain = determine_available_host(tags, zoneid, profile)
          add_host_record("#{host}.#{domain}", ip, zoneid, profile)
          return host
        rescue DNSInsertFailed => e
          log "Route53 update failed.. retrying in #{retrywait}s"
          sleep retrywait
          raise e
        end
      end
    end
  end

  def detect_first_chef_role(nodefile)
    log "detect_first_chef_role" do
      begin
        if node_data = File.open(nodefile).read.strip
          role = node_data.scan(/role\[([a-z\_\-\d]+)\]/).flatten[0]
          if role
            log("detected chef role #{role}")
            role = role.gsub(/\_/,"-")
          else
            log("role is not present in #{nodefile}")
          end
          role
        end
      rescue Exception => e
        raise "#{nodefile} is not found or invalid. Specify a cluster name using --cluster-name"
      end
    end
  end

  def detect_ip
    log "detect_ip" do
      if first_private_ip = Socket.ip_address_list.detect{|intf| intf.ipv4_private?}
        ip = first_private_ip.ip_address
      elsif first_public_ip = Socket.ip_address_list.detect{|intf| intf.ipv4? and !intf.ipv4_loopback? and !intf.ipv4_multicast? and !intf.ipv4_private?}
        ip = first_public_ip.ip_address
      else
        nil
      end
      log "detected ip: #{ip}"
      ip
    end
  end

  def determine_available_host(tags, zoneid, profile=nil)
    log "determining_available_host" do
      n = 0
      domain  = detect_domain(zoneid, profile)
      host = (tags + ["%02d" % n]).join('-')
      records = list_record_sets(zoneid, "#{host}.#{domain}", profile)
      while records.include?("#{host}.#{domain}") do
        records = list_record_sets(zoneid, "#{host}.#{domain}", profile)
        log "checking availability for #{host}.#{domain}"
        host = (tags + ["%02d" % n+=1]).join('-')
      end
      log "#{host}.#{domain} is available"
      [host, domain]
    end
  end

  def detect_domain(zoneid, profile=nil)
    log "detect_domain" do
      cmd = "aws route53 get-hosted-zone --id #{zoneid} --output text"
      cmd = "#{cmd} --profile #{profile}" if profile
      debug "exec: #{cmd}"
      result = `#{cmd} | grep HOSTEDZONE | awk '{print $4}'`.strip
      log "detected domain: #{result}"
      raise DNSQueryFailed unless $?.exitstatus.zero?
      result
    end
  end

  def list_record_sets(zoneid, hostname, profile=nil)
    log "list_record_sets" do
      cmd = "aws route53 list-resource-record-sets --hosted-zone-id #{zoneid} --output text --start-record-name #{hostname}"
      cmd = "#{cmd} --profile #{profile}" if profile
      debug "exec: #{cmd}"
      records = `#{cmd} | grep RESOURCERECORDSETS | awk '{print $2}'`.strip
      raise DNSQueryFailed unless $?.exitstatus.zero?
      records.split
    end
  end

  def record_unavailable?(record)
    `dig #{record} +short`.strip != ''
  end

  def add_host_record(host, ip, zoneid, profile = nil)
    log "add_host_record: #{host}" do
      payload = Tempfile.new('payload')
      payload.write %Q(
          {
            "Comment": "Added by hostnamer during instance bootstrap",
            "Changes": [
              {
                "Action": "CREATE",
                "ResourceRecordSet": {
                  "Name": "#{host}",
                  "Type": "A",
                  "TTL": 300,
                  "ResourceRecords": [
                    {
                      "Value": "#{ip}"
                    }
                  ]
                }
              }
            ]
          })
      payload.close
      cmd = 'aws', 'route53', 'change-resource-record-sets', '--hosted-zone-id', zoneid, '--change-batch', "file://#{payload.path}"
      cmd += ['--profile', profile] if profile
      log "exec: #{cmd.join(' ')}"
      Process.wait(spawn(cmd.join(' '), :out => '/dev/null', :err => '/dev/null'))
      raise DNSInsertFailed unless $?.exitstatus.zero?
    end
  end

  def retrying(n)
    begin
      yield
    rescue => e
      n = n - 1
      retry if n > 0
    end
  end

  def debug(msg, doprint = false)
    msg = "hostnamer: #{msg}"
    if ENV['HOSTNAMER_VERBOSE']
      if doprint
        $stderr.print(msg)
      else
        $stderr.puts(msg)
      end
    end
  end

  def log(msg, &block)
    if block
      start = Time.now
      res = nil
      log "#{msg} at=start"
      begin
        res = yield
      rescue => e
        log_error "#{msg} elapsed=#{Time.now - start}", e
        raise e
      end
      log "hostnamer: #{msg} at=finish elapsed=#{Time.now - start}"
      res
    else
      debug(msg)
      Syslog.open("hostnamer", Syslog::LOG_PID, Syslog::LOG_DAEMON | Syslog::LOG_LOCAL3)
      Syslog.log(Syslog::LOG_INFO, msg)
      Syslog.close
    end
  end

  def log_error(msg, e, dofail = false)
    debug "error #{msg}"
    Syslog.open("hostnamer", Syslog::LOG_PID, Syslog::LOG_DAEMON | Syslog::LOG_LOCAL3)
    Syslog.log Syslog::LOG_ERR, "#{msg} at=error class='#{e.class}' message='#{e.message}'"
    Syslog.close
  end

  def parse_options(argv)
    options = {}
    options[:json_attrs] = "/etc/chef/node.json"
    options[:retry_wait] = 10
    options[:retries] = 5
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: hostnamer [options]"
      opts.on "-Z", "--zone-id ZONEID", "Route 53 zone id" do |z|
        options[:zone_id] = z
      end
      opts.on "-n", "--cluster-name [NAME]", "Name of the cluster. Defaults to first chef role found under #{options[:json_attrs]}" do |c|
        options[:cluster_name] = c
      end
      opts.on "-j", "--json-attributes [PATH]", "Chef json attributes file. Defaults to #{options[:json_attrs]}" do |j|
        options[:json_attrs] = j
      end
      opts.on "-t", "--tags [TAG,TAG]", Array, "Tags to postpend, eg: --tags production,california" do |tags|
        options[:tags] = tags
      end
      opts.on "-p", "--profile [PROFILE]", "AWS user profile. Uses the current IAM or the default profile located under ~/.aws" do |p|
        options[:profile] = p
      end
      opts.on "-r", "--retries [RETRIES]", "Number of times to retry before failing. Defaults to #{options[:retries]}" do |r|
        options[:retries] = r
      end
      opts.on "-w", "--retry-wait SECONDS", "Retry wait time. Defaults to #{options[:retry_wait]}s" do |w|
        options[:retry_wait] = w
      end
      opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
        options[:verbose] = v
      end
      opts.on_tail("--version", "Show version") do
        puts Hostnamer::VERSION
        exit
      end
    end
    begin
      parser.parse!(argv)
    rescue OptionParser::InvalidOption => e
      raise "#{e.message}\n\n#{parser.help}"
    end
    options
  end

  # depricated methods

  def detect_ns_zoneid(domain)
    log "detect_ns_zoneid" do
      if zid = `dig #{domain} txt +short | grep 'zone_id' | awk '{print $2}' | sed 's/\"//'`
        if zid != ''
          log "detected zone id: #{zid}"
          zid.strip
        else
          raise "could not detect zone_id from #{domain} because \"zone_id\" TXT record is missing. Either insert a TXT record in the DNS or specify --zone-id ZONEID"
          nil
        end
      end
    end
  end

  def detect_soa_ttl(domain)
    log "detect_soa_ttl" do
      if answer = `dig +nocmd +noall +answer soa #{domain}`
        # get the TTL of SOA record. The answer will look something like
        # demandbase.co. 60  IN  SOA ns-1659.awsdns-15.co.uk. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400
        ttl = answer.split(' ')[1]
        log "ttl is #{ttl}"
        ttl
      end
    end
  end

  def detect_region
    log "detect region" do
      aws_region=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | grep -Po "(us|sa|eu|ap)-(north|south)?(east|west)?-[0-9]+"`
    end
  end
end
