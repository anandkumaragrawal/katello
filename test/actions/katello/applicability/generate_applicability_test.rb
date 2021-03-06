require 'katello_test_helper'

module ::Actions::Katello::Applicability::Host
  class GenerateApplicabilityTest < ActiveSupport::TestCase
    include Dynflow::Testing
    include Support::Actions::Fixtures
    include FactoryBot::Syntax::Methods

    before :all do
      User.current = users(:admin)
      @host = FactoryBot.build(:host, :with_content, :with_subscription, :content_view => katello_content_views(:library_dev_view),
                               :lifecycle_environment => katello_environments(:library))
      @host.save!
      SETTINGS[:katello][:katello_applicability] = true
    end

    after :all do
      SETTINGS[:katello][:katello_applicability] = false
      ::Setting['applicability_batch_size'] = 50
    end

    describe 'Host Generate Applicability using Katello Applicability' do
      let(:action_class) { ::Actions::Katello::Host::GenerateApplicability }

      it 'runs' do
        Katello::ApplicableHostQueue.expects(:push_host).with(@host.id).times(5)
        Katello::EventQueue.expects(:push_event).with(::Katello::Events::GenerateHostApplicability::EVENT_TYPE, 0)

        ForemanTasks.sync_task(action_class, [@host, @host, @host, @host, @host])
      end
    end
  end
end
