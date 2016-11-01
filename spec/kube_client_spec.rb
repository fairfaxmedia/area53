describe KubeClient do
  let(:logger) { Logger.new(STDOUT) }
  let(:version) { 'v1' }
  let(:server_suffix) { 'api' }
  let(:kube_client) { double(:kubeclient, watch_services: true) }

  before { allow(subject).to receive(:create_client).and_return(kube_client) }

  subject { described_class.new(logger, version, server_suffix) }

  describe 'instance variables' do
    it { expect(subject.instance_variable_get(:@logger)).to eq(logger) }
    it { expect(subject.instance_variable_get(:@version)).to eq(version) }
    it { expect(subject.instance_variable_get(:@server_suffix)).to eq(server_suffix) }
  end

  describe 'delegators' do
    describe '#watch_services' do
      it 'delegates to client' do
        expect(kube_client).to receive(:watch_services).with(
          label_selector: 'dns=route53'
        )
        subject.watch_services
      end
    end

    describe '#watch_ingresses' do
      it 'delegates to client' do
        expect(kube_client).to receive(:watch_entities).with('Ingress')
        subject.watch_ingresses
      end
    end
  end
end
