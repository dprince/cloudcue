require 'test_helper'

class PoolTest < ActiveSupport::TestCase

  fixtures :users
  fixtures :accounts
  fixtures :pools

  test "create pool" do
    pool = Pool.new(
      :flavor_ref => 1,
      :image_ref => 1,
      :size => 4,
      :user_id => users(:admin).id
    )

    assert pool.valid?, "Pool server should be valid."
    assert pool.save, "Pool server should have been saved."
  end

  test "size is a number" do
    pool = Pool.new(
      :flavor_ref => 1,
      :image_ref => 1,
      :size => "asdf",
      :user_id => users(:admin).id
    )

    assert_equal false, pool.valid?, "Pool server should not be valid."
  end

  test "requires size" do
    pool = Pool.new(
      :flavor_ref => 1,
      :image_ref => 1,
      :user_id => users(:admin).id
    )

    assert_equal false, pool.valid?, "Pool server should not be valid."
  end

  test "requires flavor_ref" do
    pool = Pool.new(
      :image_ref => 1,
      :size => 4,
      :user_id => users(:admin).id
    )

    assert_equal false, pool.valid?, "Pool server should not be valid."
  end

  test "requires image_ref" do
    pool = Pool.new(
      :flavor_ref => 1,
      :size => 4,
      :user_id => users(:admin).id
    )

    assert_equal false, pool.valid?, "Pool server should not be valid."
  end

  test "requires user" do
    pool = Pool.new(
      :image_ref => 1,
      :flavor_ref => 1,
      :size => 4
    )

    assert_equal false, pool.valid?, "Pool server should not be valid."
  end

  test "sync creates server" do
    pool = Pool.create(
      :image_ref => 1,
      :flavor_ref => 1,
      :size => 1,
      :user_id => users(:admin).id
    )
  
    AsyncExec.jobs.clear
    pool.sync
    assert_not_nil AsyncExec.jobs[CreatePoolServer]
    AsyncExec.jobs.clear
  end

  test "sync deletes server" do
    AsyncExec.jobs.clear
    pool = pools(:admin_pool)
    pool.update_attribute(:size, 1)
    pool.sync
    assert_not_nil AsyncExec.jobs[MakePoolServerHistorical]
    AsyncExec.jobs.clear
  end

  test "sync updates server" do
    AsyncExec.jobs.clear
    pool = pools(:admin_pool)
    pool.update_attribute(:image_ref, 999) #fixture uses 1
    pool.sync
    assert_not_nil AsyncExec.jobs[CreatePoolServer]
    assert_not_nil AsyncExec.jobs[MakePoolServerHistorical]
    AsyncExec.jobs.clear
  end

end
