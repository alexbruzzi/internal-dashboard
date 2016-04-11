require 'cequel'

module Dashboard
  module Analytics

    def self.registered(app)

      # Analytics of API hits
      app.get '/apihits' do

      end

    end
  end
end