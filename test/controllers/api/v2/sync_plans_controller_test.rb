# encoding: utf-8

require "katello_test_helper"

module Katello
  class Api::V2::SyncPlansControllerTest < ActionController::TestCase
    include Support::ForemanTasks::Task

    def models
      @organization = get_organization
      @sync_plan = katello_sync_plans(:sync_plan_hourly)
      @products = katello_products(:fedora, :redhat, :empty_product)
    end

    def permissions
      @resource_type = "Katello::SyncPlan"
      @view_permission = :view_sync_plans
      @create_permission = :create_sync_plans
      @update_permission = :edit_sync_plans
      @destroy_permission = :destroy_sync_plans

      @sync_permission = :sync_products
      @read_products_permission = :view_products
      @update_products_permission = :edit_products
    end

    def setup
      setup_controller_defaults_api
      login_user(users(:admin))
      @request.env['HTTP_ACCEPT'] = 'application/json'
      Repository.any_instance.stubs(:sync_status).returns(PulpSyncStatus.new({}))
      Repository.any_instance.stubs(:last_sync).returns(Time.now.to_s)
      models
      permissions
    end

    def test_index
      get :index, params: { :organization_id => @organization.id }

      assert_response :success
      assert_template 'api/v2/sync_plans/index'
    end

    def test_index_protected
      allowed_perms = [@view_permission]
      denied_perms = [@create_permission, @update_permission, @destroy_permission]

      assert_protected_action(:index, allowed_perms, denied_perms, [@organization]) do
        get :index, params: { :organization_id => @organization.id }
      end
    end

    def test_create
      valid_attr = {
        :name => 'Hourly Sync Plan',
        :sync_date => '2014-01-09 17:46:00 +0000',
        :interval => 'hourly',
        :description => 'This is my cool new product.',
        :enabled => true
      }
      post :create, params: { :organization_id => @organization.id, :sync_plan => valid_attr }

      assert_response :success
      assert_template 'api/v2/common/create'
      response = JSON.parse(@response.body)
      assert response.key?('name')
      assert_equal valid_attr[:name], response['name']
      assert response.key?('sync_date')
      assert_equal Time.parse(valid_attr[:sync_date]), Time.parse(response['sync_date'])
      assert response.key?('interval')
      assert_equal valid_attr[:interval], response['interval']
      assert response.key?('description')
      assert_equal valid_attr[:description], response['description']
      assert response.key?('enabled')
      assert_equal valid_attr[:enabled], response['enabled']
    end

    test_attributes :pid => 'b4686463-69c8-4538-b040-6fb5246a7b00'
    def test_create_fail
      post :create, params: { :organization_id => @organization.id, :sync_plan => {:sync_date => '2014-01-09 17:46:00',
                                                                                   :description => 'This is my cool new sync plan.'} }

      assert_response :unprocessable_entity
      response = JSON.parse(@response.body)
      assert response.key?('errors')
      assert response['errors'].key?('name')
      assert_equal 'can\'t be blank', response['errors']['name'][0]
      assert response['errors'].key?('interval')
      assert_equal 'is not included in the list', response['errors']['interval'][0]
    end

    def test_create_protected
      allowed_perms = [@create_permission]
      denied_perms = [@view_permission, @update_permission, @destroy_permission]

      assert_protected_action(:create, allowed_perms, denied_perms, [@organization]) do
        post :create, params: { :organization_id => @organization.id, :sync_plan => {:name => 'Hourly Sync Plan',
                                                                                     :sync_date => '2014-01-09 17:46:00',
                                                                                     :interval => 'hourly'} }
      end
    end

    def test_update
      datetime_format = '%Y/%m/%d %H:%M:%S %z'
      update_attrs = {
        :name => 'New Name',
        :interval => 'weekly',
        :sync_date => Time.now.utc.strftime(datetime_format),
        :description => 'New Description',
        :enabled => false
      }
      put :update, params: { :id => @sync_plan.id, :organization_id => @organization.id, :sync_plan => update_attrs }

      assert_response :success
      assert_template 'api/v2/sync_plans/show'
      assert_equal update_attrs[:name], assigns[:sync_plan].name
      assert_equal update_attrs[:interval], assigns[:sync_plan].interval
      assert_equal update_attrs[:enabled], assigns[:sync_plan].enabled
      assert_equal update_attrs[:sync_date], assigns[:sync_plan].sync_date.strftime(datetime_format)
    end

    test_attributes :pid => '8c981174-6f55-49c0-8baa-40e5c3fc598c'
    def test_update_with_invalid_interval
      put :update, params: { :id => @sync_plan.id, :organization_id => @organization.id, :sync_plan => { :interval => 'invalid_interval'} }
      assert_response :unprocessable_entity
      assert_match 'Validation failed: Interval is not included in the list', @response.body
    end

    def test_update_protected
      allowed_perms = [@update_permission]
      denied_perms = [@view_permission, @create_permission, @destroy_permission]

      assert_protected_action(:update, allowed_perms, denied_perms, [@organization]) do
        put :update, params: { :id => @sync_plan.id, :organization_id => @organization.id, :sync_plan => {:description => 'new description.'} }
      end
    end

    def test_destroy
      assert_sync_task(::Actions::Katello::SyncPlan::Destroy) do |sync_plan|
        sync_plan.id.must_equal @sync_plan.id
      end

      delete :destroy, params: { :organization_id => @organization.id, :id => @sync_plan.id }

      assert_response :success
      assert_template 'api/v2/sync_plans/show'
    end

    def test_destroy_protected
      allowed_perms = [@destroy_permission]
      denied_perms = [@view_permission, @create_permission, @update_permission]

      assert_protected_action(:destroy, allowed_perms, denied_perms, [@organization]) do
        delete :destroy, params: { :organization_id => @organization.id, :id => @sync_plan.id }
      end
    end

    def test_add_products
      product_ids = @products.collect { |p| p.id.to_s }
      ::ForemanTasks.expects(:sync_task).with(::Actions::Katello::SyncPlan::AddProducts, @sync_plan, product_ids)

      put :add_products, params: { :id => @sync_plan.id, :organization_id => @organization.id, :product_ids => product_ids }

      assert_response :success
      assert_template 'api/v2/sync_plans/show'
    end

    def test_add_products_protected
      allowed_perms = [@view_permission]
      denied_perms = [@create_permission, @update_permission, @destroy_permission]

      assert_protected_action(:add_products, allowed_perms, denied_perms, [@organization]) do
        put :add_products, params: { :id => @sync_plan.id, :organization_id => @organization.id, :product_ids => @products.collect { |p| p.id } }
      end
    end

    def test_remove_products
      product_ids = @products.collect { |p| p.id.to_s }
      ::ForemanTasks.expects(:sync_task).with(::Actions::Katello::SyncPlan::RemoveProducts, @sync_plan, product_ids)

      put :remove_products, params: { :id => @sync_plan.id, :organization_id => @organization.id, :product_ids => product_ids }

      assert_response :success
      assert_template 'api/v2/sync_plans/show'
    end

    def test_remove_products_protected
      allowed_perms = [@view_permission]
      denied_perms = [@create_permission, @update_permission, @destroy_permission]

      assert_protected_action(:remove_products, allowed_perms, denied_perms, [@organization]) do
        put :remove_products, params: { :id => @sync_plan.id, :organization_id => @organization.id, :product_ids => @products.collect { |p| p.id } }
      end
    end

    def test_sync
      repo_ids = @sync_plan.products.collect { |product| product.repositories.map(&:id) }
      repo_ids.flatten!

      assert_async_task(::Actions::BulkAction) do |action_class, ids|
        assert_equal action_class, ::Actions::Katello::Repository::Sync
        assert_equal repo_ids, ids
      end

      put :sync, params: { :id => @sync_plan.id, :organization_id => @organization.id }

      assert_response :success
    end

    def test_sync_protected
      allowed_perms = [@sync_permission]
      denied_perms = [@create_permission, @update_permission, @destroy_permission]

      assert_protected_action(:sync, allowed_perms, denied_perms, [@organization]) do
        put :sync, params: { :id => @sync_plan.id, :organization_id => @organization.id }
      end
    end
  end
end
