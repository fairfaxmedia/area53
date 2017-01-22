describe Route53Client do
  let(:logger) { Logger.new(STDOUT) }
  let(:hosted_zone_id) { 'sample_hosted_zone_id' }
  let(:hosted_zone_name) { 'sample_hosted_zone' }
  let(:hosted_zone) do
    RecursiveOpenStruct.new(
      hosted_zone: {
        name: hosted_zone_name
      }
    )
  end
  let(:client) { instance_double(Aws::Route53::Client, get_hosted_zone: hosted_zone) }

  before { allow(subject).to receive(:client).and_return(client) }

  subject { Route53Client.new(logger, hosted_zone_id) }

  describe 'instance variables' do
    it { expect(subject.instance_variable_get(:@logger)).to eq(logger) }
    it { expect(subject.instance_variable_get(:@hosted_zone_id)).to eq(hosted_zone_id) }
  end

  describe '#get_action' do
    type_mappings = {
      'ADDED' => 'UPSERT',
      'MODIFIED' => 'UPSERT',
      'DELETED' => 'DELETE',
      nil => nil
    }

    type_mappings.each do |type, action|
      context "when notice type is #{type}" do
        let(:notice) { RecursiveOpenStruct.new(type: type) }
        it { expect(subject.get_action(notice)).to eq(action) }
      end
    end
  end

  describe '#get_hosted_zone_name' do
    it { expect(subject.get_hosted_zone_name).to eq(hosted_zone_name) }
  end

  describe '#change_dns' do
    let(:host_name) { 'sample_hostname' }
    let(:resource_value) { 'sample_value' }
    let(:type) { 'CNAME' }
    let(:action) { 'CREATE' }
    let(:route53_payload) do
      {
        hosted_zone_id: hosted_zone_id,
        change_batch: {
          changes: [{
            action: action,
            resource_record_set: {
              name: host_name,
              type: type,
              ttl: 5,
              resource_records: [{
                value: resource_value
              }]
            }
          }]
        }
      }
    end

    context 'when no exception is thrown' do
      it 'calls client#change_resource_record_sets' do
        expect(client).to receive(:change_resource_record_sets).with(route53_payload)
        subject.change_dns(host_name, resource_value, type, action)
      end
    end

    context 'when Aws::Route53::Errors::ServiceError is thrown' do
      let(:error_message) { 'An error occurred' }
      let(:request_context) { instance_double(Seahorse::Client::RequestContext) }
      let(:exception) do
        Aws::Route53::Errors::ServiceError.new(request_context, error_message)
      end

      before do
        allow(client).to receive(
          :change_resource_record_sets
        ).with(route53_payload).and_raise(
          exception
        )
      end

      it 'logs error message' do
        expect(logger).to receive(:error).with(error_message)
        subject.change_dns(host_name, resource_value, type, action)
      end
    end

    describe 'DNS time to live' do
      context 'when TTL is configured' do
        before do
          ENV['ROUTE53_TTL'] = '60'
        end

        it 'uses the correct TTL' do
          expect(client).to receive(:change_resource_record_sets) do |hash|
            expect(hash.dig(:change_batch, :changes, 0, :resource_record_set, :ttl)).to eq(60)
          end
          subject.change_dns(host_name, resource_value, type, action)
        end
      end

      context 'when TTL is not configured' do
        before do
          ENV.delete('ROUTE53_TTL')
        end

        it 'uses a default TTL' do
          expect(client).to receive(:change_resource_record_sets) do |hash|
            expect(hash.dig(:change_batch, :changes, 0, :resource_record_set, :ttl)).to be_kind_of(Integer)
          end
          subject.change_dns(host_name, resource_value, type, action)
        end
      end
    end
  end
end
