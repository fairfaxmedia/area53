require_relative '../kube_client'
require_relative '../route53_client'
require_relative '../watchers/service_watcher'
require_relative '../watchers/ingress_watcher'

require 'ffx/container_logging'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
