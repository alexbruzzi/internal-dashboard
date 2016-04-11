require 'octocore'

module Dashboard
  module Helpers

    include Octo::Helpers::ClientHelper
    include Octo::Helpers::KongHelper

    # Create a new Client
    # @param [String] username The name of the client
    # @param [String] email The email of the client
    # @param [String] password The password of the client
    # @return [String] The status of request
    def create_consumer(username, email, password)
      add_consumer(username, email, password)
    end

    # Add a Kong ratelimiting plugin
    # @param [String] apikey The apikey of the client
    # @param [String] consumer_id The consumer_id of the client
    # @return [String] Plugin Id or Blank
    def create_ratelimiting_plugin(apikey, consumer_id)
      config = settings.kong[:ratelimiting]
      response = add_ratelimiting_plugin(apikey, consumer_id, config)
    end

  end
end