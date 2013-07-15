require 'test_helper'

class PoolServerTest < ActiveSupport::TestCase

  fixtures :users
  fixtures :accounts
  fixtures :pools
  fixtures :pool_servers

  test "create pool server" do

    pool = PoolServer.new(
      :flavor_ref => 1,
      :image_ref => 1,
      :account_id => users(:admin).account.id,
      :pool_id => pools(:admin_pool).id
    )

    assert pool.valid?, "Pool server should be valid."
    assert pool.save, "Pool server should have been saved."
    assert pool.create_pool_server
    assert_equal false, pool.historical, "Pool server should not be historical."

  end

  test "create requires flavor ref" do

    pool = PoolServer.new(
      :image_ref => 1,
      :account_id => users(:admin).account.id,
      :pool_id => pools(:admin_pool).id
    )

    assert_equal false, pool.valid?, "Pool server should not be valid."

  end

  test "create requires image ref" do

    pool = PoolServer.new(
      :flavor_ref => 1,
      :account_id => users(:admin).account.id,
      :pool_id => pools(:admin_pool).id
    )

    assert_equal false, pool.valid?, "Pool server should not be valid."

  end

  test "create requires pool" do

    pool = PoolServer.new(
      :image_ref => 1,
      :flavor_ref => 1,
      :account_id => users(:admin).account.id
    )

    assert_equal false, pool.valid?, "Pool server should not be valid."

  end

  test "create requires account" do

    pool = PoolServer.new(
      :image_ref => 1,
      :flavor_ref => 1,
      :pool_id => pools(:admin_pool).id
    )

    assert_equal false, pool.valid?, "Pool server should not be valid."

  end

end
