describe ServiceWatcher do
  let(:logger) { Logger.new(STDOUT) }
  let(:route53_client) do
    instance_double(Route53Client, get_hosted_zone_name: hosted_zone_name)
  end
  let(:hosted_zone_name) { 'sample_hosted_zone' }
  let(:hostname) { 'sample_hostname' }
  let(:namespace) { 'sample_namespace' }
  let(:svc) do
    RecursiveOpenStruct.new(
      metadata: {
        namespace: namespace,
        annotations: annotations
      }
    )
  end

  subject { ServiceWatcher.new(logger, route53_client) }

  describe 'instance variables' do
    it { expect(subject.instance_variable_get(:@logger)).to eq(logger) }
    it { expect(subject.instance_variable_get(:@route53_client)).to eq(route53_client) }
  end

  describe '#get_domain' do
    context 'when dnsDashSubdomains annotation is true' do
      let(:annotations) do
        {
          dnsHostName: hostname,
          dnsDashSubdomains: 'true',
          dnsIncludeNamespace: 'true'
        }
      end

      it 'creates a dash-delimited subdomain' do
        expect(
          subject.send(:get_domain, svc)
        ).to eq(
          "#{subject.send(:domain, svc).join('-')}.#{hosted_zone_name}"
        )
      end
    end

    context 'when dnsDashSubdomains annotation is not present' do
      let(:annotations) do
        {
          dnsHostName: hostname,
          dnsIncludeNamespace: 'true'
        }
      end

      it 'creates a dot-delimited subdomain' do
        expect(
          subject.send(:get_domain, svc)
        ).to eq(
          "#{subject.send(:domain, svc).join('.')}.#{hosted_zone_name}"
        )
      end
    end
  end

  describe '#domain' do
    context 'when dnsIncludeNamespace annotation is true' do
      let(:annotations) do
        {
          dnsHostName: hostname,
          dnsDashSubdomains: 'true',
          dnsIncludeNamespace: 'true'
        }
      end

      it 'returns hostname and namespace' do
        expect(subject.send(:domain, svc)).to eq([hostname, namespace])
      end
    end

    context 'when dnsIncludeNamespace annotation not present' do
      let(:annotations) do
        {
          dnsHostName: hostname,
          dnsDashSubdomains: 'true'
        }
      end

      it 'returns hostname' do
        expect(subject.send(:domain, svc)).to eq([hostname])
      end
    end
  end
end
