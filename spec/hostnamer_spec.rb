require 'hostnamer'
require 'tempfile'

describe HostNamer do
  subject { HostNamer }
  it "detects ip" do
    expect(subject.detect_ip).to match /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/
  end

  it "checks the dns for the hostname availability" do
    expect(subject.record_unavailable? "google.com").to eq true
  end

  it "returns the first chef role when multiple roles are present" do
    file = Tempfile.new('node')
    file.write %Q("{"chef_environment": "staging", "name": "adopsInstance", "run_list": ["role[adops]","role[adops-web]"]})
    file.close
    expect(subject.detect_first_chef_role(file.path)).to eq "adops"
    file.unlink
  end

end
