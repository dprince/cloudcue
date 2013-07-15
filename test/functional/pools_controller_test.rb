require 'test_helper'

class PoolsControllerTest < ActionController::TestCase

  include AuthTestHelper

  fixtures :users
  fixtures :pools

  test "should not get index" do
    get :index
    assert_response 302
  end

  test "should get index as admin" do

    login_as(:admin)
    get :index
    assert_response :success
    assert_not_nil assigns(:pools)

  end

  test "should create pool" do
    login_as(:bob)
    before_count = users(:bob).pools.size
    assert_difference('Pool.count') do
      post :create, :pool => {:flavor_ref => "2", :image_ref => "1", :size => 4}
    end
    assert_response 201
    after_count = User.find(users(:bob).id).pools.size
    assert after_count > before_count, "Failed to associate pool with user."
    assert_response :success
  end

  test "admin update pool" do
    login_as(:admin)
    put :update, :id => pools(:jim_pool).to_param, :pool => {:flavor_ref => "9", :image_ref => "1", :size => 4}
    assert_redirected_to pool_path(assigns(:pool))
  end

  test "user update pool" do
    login_as(:jim)
    put :update, :id => pools(:jim_pool).to_param, :pool => {:flavor_ref => "9", :image_ref => "1", :size => 4}
    assert_redirected_to pool_path(assigns(:pool))
  end

 test "user should not update another users pool" do
    login_as(:bob)
    put :update, :id => pools(:jim_pool).to_param, :pool => {:flavor_ref => "2", :image_ref => "1", :size => 4}
    assert_response 401
  end

  test "user destroy pool" do
    login_as(:jim)
    delete :destroy, :id => pools(:jim_pool).to_param
    assert_equal true, Pool.find(pools(:jim_pool).id).historical
  end

end
