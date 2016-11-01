describe IngressWatcher do
  let(:hosted_zone_name) { 'sample_hosted_zone' }
  let(:action) { 'UPSERT' }
  let(:logger) { Logger.new(STDOUT) }
  let(:route53_client) do
    instance_double(
      Route53Client,
      get_action: action,
      get_hosted_zone_name: hosted_zone_name
    )
  end
  let(:elb) { 'sample_elb' }

  subject { IngressWatcher.new(logger, route53_client, elb) }

  describe 'instance variables' do
    it { expect(subject.instance_variable_get(:@logger)).to eq(logger) }
    it { expect(subject.instance_variable_get(:@kube_client)).to be_a(KubeClient) }
    it { expect(subject.instance_variable_get(:@route53_client)).to eq(route53_client) }
    it { expect(subject.instance_variable_get(:@elb)).to eq(elb) }
  end

  describe '#new_notice' do
    let(:notice) { RecursiveOpenStruct.new(object: ingress) }
    let(:ingress) do
      RecursiveOpenStruct.new(
        spec: {
          rules: [
            {
              host: nil
            }
          ]
        }
      )
    end

    context 'when ingress has no host' do
      it { expect(subject.send(:new_notice, notice)).to(be_falsey) }
    end

    context 'when host is invalid' do
      before { ingress.spec.rules.first['host'] = 'invalid_hosted_zone' }

      it { expect(subject.send(:new_notice, notice)).to(be_falsey) }

      it 'calls logger#error' do
        expect(logger).to receive(:error)
        subject.send(:new_notice, notice)
      end
    end

    context 'when host is valid' do
      before do
        ingress.spec.rules.first['host'] = hosted_zone_name
        allow(route53_client).to receive(:change_dns)
      end

      it 'calls route53_client#change_dns' do
        expect(route53_client).to receive(:change_dns).with(
          "#{hosted_zone_name.chomp('.')}.", elb, 'CNAME', action
        )
        subject.send(:new_notice, notice)
      end

      it 'calls logger#info' do
        expect(logger).to receive(:info).exactly(2).times
        subject.send(:new_notice, notice)
      end
    end
  end
end
