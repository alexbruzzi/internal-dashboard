require 'cequel'

module Dashboard
  module Analytics

    def self.registered(app)

      app.get '/apihits' do

      return 1
      end

    end
  end
end