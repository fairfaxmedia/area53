describe Area53 do
  let(:watcher) do
    instance_double(
      'Watcher',
      :run
    )
  end

  describe 'startup' do
    context 'ELB environment variable set' do
      before do
        ENV['ELB'] = 'unique-id.eu-west-1.elb.amazonaws.com'
      end

      it 'starts both watchers' do
        expect(watcher).to receive(:run).twice
        expect(ServiceWatcher).to receive(:new).once.and_return(watcher)
        expect(IngressWatcher).to receive(:new).once.and_return(watcher)
        subject.run
      end
    end

    context 'ELB environment variable not set' do
      before do
        ENV.delete('ELB')
      end

      it 'starts just the Service watcher' do
        expect(watcher).to receive(:run).once
        expect(ServiceWatcher).to receive(:new).once.and_return(watcher)
        expect(IngressWatcher).to_not receive(:new)
        subject.run
      end
    end
  end
end
