require 'test_helper'

class ServerTest < ActiveSupport::TestCase

	fixtures :server_groups
	fixtures :servers
	fixtures :users
	fixtures :accounts

	test "create server" do

		server=Server.new(
			:name => "test1",
			:description => "test description",
			:flavor_id => 1,
			:image_id => 1,
			:base64_command => "echo hello",
			:account_id => users(:bob).account.id
		)

		group=server_groups(:two)
		group.servers << server

		assert server.valid?, "Server should be valid."
		assert server.save, "Server should have been saved."
		assert_equal false, server.historical, "Server should not be historical."
		assert_not_nil server.server_command, "ServerCommand should not be nil."

		server=Server.find(server.id)

		assert_equal users(:bob).account, server.account

	end

	test "create server with dash and dot" do

		server=Server.new(
			:name => "test1-.",
			:description => "test description",
			:flavor_id => 1,
			:image_id => 1,
			:account_id => users(:bob).account.id
		)

		group=server_groups(:two)
		group.servers << server

		assert server.valid?, "Server should be valid."
		assert server.save, "Server should have been saved."

		server=Server.find(server.id)

		assert_equal users(:bob).account, server.account

	end

	test "missing name" do

		server=Server.new(
			:description => "test description",
			:flavor_id => 1,
			:image_id => 1,
			:account_id => users(:bob).account.id
		)

		group=server_groups(:two)
		group.servers << server

		assert !server.valid?, "Server should not be valid."
		assert !server.save, "Server should not be saved."

	end

	test "missing description" do

		server=Server.new(
			:name => "test1",
			:flavor_id => 1,
			:image_id => 1,
			:account_id => users(:bob).account.id
		)

		group=server_groups(:two)
		group.servers << server

		assert !server.valid?, "Server should not be valid."
		assert !server.save, "Server should not be saved."

	end

	test "missing group" do

		server=Server.new(
			:name => "test1",
			:description => "test description",
			:flavor_id => 1,
			:image_id => 1,
			:account_id => users(:bob).account.id
		)

		assert !server.valid?, "Server should not be valid."
		assert !server.save, "Server should not be saved."

	end

	test "verify server names are unique within a group" do

		server=Server.new(
			:name => servers(:one).name,
			:description => "test description",
			:flavor_id => 1,
			:image_id => 1,
			:account_id => users(:bob).account.id
		)
		group=server_groups(:one)
		group.servers << server

		assert !server.valid?, "Server must have unique names."
		assert !server.save, "Server must have unique names."

	end

	test "create server with invalid name" do

		server=Server.new(
			:name => "test 1_*",
			:description => "test description",
			:flavor_id => 1,
			:image_id => 1,
			:account_id => users(:bob).account.id
		)

		group=server_groups(:two)
		group.servers << server

		assert !server.valid?, "Server should be not be valid. (invalid hostname)"
		assert !server.save, "Server not should have been saved. (invalid hostname)"

	end

end
