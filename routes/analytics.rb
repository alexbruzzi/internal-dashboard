require 'cequel'

module Dashboard
  module Analytics

    def self.registered(app)

      def checkEnterprise(enterpriseId)
        return Octo::Enterprise.findOrCreate({id: enterpriseId})
      end

      app.get '/apihits' do

      return 1
      end

    end
  end
end