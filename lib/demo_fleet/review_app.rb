# frozen_string_literal: true

module DemoFleet
  class ReviewAppLookup
    def url_for(cpflow_app_name:, branch_name:)
      raise NotImplementedError, 'CPFlow URL lookup is provided by the executor environment'
    end
  end
end
