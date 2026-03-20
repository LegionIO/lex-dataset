# frozen_string_literal: true

module Legion
  module Extensions
    module Dataset
      class Client
        include Runners::Dataset
        include Runners::Experiment
        include Runners::Sampling

        def initialize(db: nil, **opts)
          @db   = db
          @opts = opts
        end
      end
    end
  end
end
