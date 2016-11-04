class Route53Client
  require 'aws-sdk'

  def initialize(logger, hosted_zone_id)
    @logger = logger
    @hosted_zone_id = hosted_zone_id
  end

  def client
    @_client ||= create_client
  end

  def create_client
    Aws::Route53::Client.new
  end

  def get_action(notice)
    case notice.type
      when 'ADDED', 'MODIFIED'
        'UPSERT'
      when 'DELETED'
        'DELETE'
      else
        nil
    end
  end

  def get_hosted_zone_name
    @hosted_zone_name ||= client.get_hosted_zone(id: ENV['HOSTED_ZONE_ID']).hosted_zone.name
  end

  def change_dns(host_name, resource_value, type, action)
    client.change_resource_record_sets({
                                           hosted_zone_id: @hosted_zone_id,
                                           change_batch: {
                                               changes: [{
                                                             action: action,
                                                             resource_record_set: {
                                                                 name: host_name,
                                                                 type: type,
                                                                 ttl: dns_ttl,
                                                                 resource_records: [{
                                                                                        value: resource_value
                                                                                    }]
                                                             }
                                                         }]
                                           }
                                       })
  rescue Aws::Route53::Errors::ServiceError => e
    @logger.error(e.message)
  end

  def dns_ttl
    ENV['ROUTE53_TTL'].present? && ENV['ROUTE53_TTL'].to_i || 5
  end
end
