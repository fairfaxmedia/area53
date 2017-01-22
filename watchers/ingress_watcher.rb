class IngressWatcher
  def initialize(logger, route53_client, elb)
    @logger = logger
    @kube_client = KubeClient.new(logger, 'extensions/v1beta1', 'apis')
    @route53_client = route53_client
    @elb = elb
  end

  def run
    loop do
      @logger.info(watcher: 'Ingress', status: 'startup', hosted_zone_id: ENV['HOSTED_ZONE_ID'])
      @kube_client.watch_ingresses.each do |notice|
        begin
          new_notice(notice)
        rescue => ex
          logger.error(watcher: 'Ingress', status: 'end_watch', error: ex)
        end
      end
      @logger.info(watcher: 'Ingress', status: 'end_all_watch')
    end
  end

  private

  def new_notice(notice)
    action = @route53_client.get_action(notice)
    return if action.nil?
    @logger.info(watcher: 'Ingress', status: 'new_notice', action: action)

    ingress = notice.object
    return if ingress.spec.rules[0]['host'].nil?
    domain = ingress.spec.rules[0]['host'].chomp('.')
    domain << '.'

    unless domain.include? @route53_client.get_hosted_zone_name
      @logger.error(watcher: 'Ingress', status: 'Invalid host', domain: domain, hosted_zone: @route53_client.get_hosted_zone_name)
      return
    end

    @logger.info(watcher: 'Ingress', status: 'change_dns', domain: domain, destination: elb(ingress), type: 'CNAME', action: action)
    @route53_client.change_dns(domain, elb(ingress), 'CNAME', action)
  end

  def elb(ingress)
    ingress&.metadata&.annotations&.elb || @elb
  end
end
