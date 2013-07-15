class Init < ActiveRecord::Migration

  def self.up

    create_table "accounts" do |t|
      t.string   "username"
      t.string   "api_key"
      t.string   "region"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "user_id"
      t.string   "connection_type", :default => "rackspace"
      t.string   "auth_url",        :default => ""
    end

    add_index "accounts", ["user_id"], :name => "index_accounts_on_user_id"

    create_table "images" do |t|
      t.string   "name",                          :null => false
      t.string   "image_ref",                     :null => false
      t.string   "os_type"
      t.integer  "account_id",                    :null => false
      t.boolean  "is_active",  :default => false, :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "pools", :force => true do |t|
      t.string   "image_ref"
      t.string   "flavor_ref"
      t.integer  "size"
      t.integer  "user_id"
      t.boolean  "historical", :default => false
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "pool_servers", :force => true do |t|
      t.integer  "pool_id"
      t.integer  "account_id"
      t.string   "flavor_ref",                              :null => false
      t.string   "image_ref",                               :null => false
      t.string   "external_ip_addr"
      t.string   "internal_ip_addr"
      t.string   "cloud_server_id"
      t.string   "status",           :default => "Pending", :null => false
      t.string   "error_message"
      t.boolean  "historical",       :default => false
      t.text     "private_key"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "pool_servers", ["cloud_server_id"], :name => "index_pool_servers_on_cloud_server_id"
    add_index "pool_servers", ["historical"], :name => "index_pool_servers_on_historical"

    create_table "server_commands", :force => true do |t|
      t.integer  "server_id",  :null => false
      t.text     "command",    :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "server_commands", ["server_id"], :name => "index_server_commands_on_server_id"

    create_table "server_errors", :force => true do |t|
      t.string   "error_message",          :null => false
      t.integer  "server_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "cloud_server_id_number"
    end

    add_index "server_errors", ["cloud_server_id_number"], :name => "index_server_errors_on_cloud_server_id_number"

    create_table "server_groups", :force => true do |t|
      t.string   "name",                                    :null => false
      t.string   "description",                             :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "domain_name"
      t.string   "owner_name"
      t.boolean  "historical",           :default => false
      t.integer  "user_id"
    end

    add_index "server_groups", ["historical"], :name => "index_server_groups_on_historical"

    create_table "servers", :force => true do |t|
      t.string   "name",                                              :null => false
      t.string   "description",                                       :null => false
      t.string   "external_ip_addr"
      t.string   "internal_ip_addr"
      t.string   "cloud_server_id_number"
      t.string   "flavor_id",                                         :null => false
      t.string   "image_id",                                          :null => false
      t.integer  "server_group_id",                                   :null => false
      t.boolean  "gateway",         :default => false,         :null => false
      t.string   "status",           :default => "Pending", :null => false
      t.integer  "retry_count",            :default => 0,             :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "error_message"
      t.boolean  "historical",             :default => false
      t.integer  "account_id"
      t.string   "type",                   :default => "LinuxServer"
      t.string   "admin_password"
    end

    add_index "servers", ["cloud_server_id_number"], :name => "index_servers_on_cloud_server_id_number"
    add_index "servers", ["historical"], :name => "index_servers_on_historical"

    create_table "ssh_keypairs", :force => true do |t|
      t.integer  "server_group_id", :null => false
      t.text     "public_key",      :null => false
      t.text     "private_key",     :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "ssh_keypairs", ["server_group_id"], :name => "index_ssh_keypairs_on_server_group_id"

    create_table "ssh_public_keys", :force => true do |t|
      t.string   "description",     :null => false
      t.text     "public_key",      :null => false
      t.integer  "server_group_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "user_id"
    end

    create_table "users", :force => true do |t|
      t.string   "username",                           :null => false
      t.string   "first_name",                         :null => false
      t.string   "last_name",                          :null => false
      t.string   "hashed_password",                    :null => false
      t.string   "salt",                               :null => false
      t.boolean  "is_active",       :default => true,  :null => false
      t.boolean  "is_admin",        :default => false, :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    execute "INSERT INTO accounts (id, username, api_key, user_id) VALUES (1, NULL, NULL, 1)"

    execute "INSERT INTO users (id, username, first_name, last_name, hashed_password, salt, is_active, is_admin) VALUES (1, 'admin', 'The', 'Administrator', 'eec2a57364af9c8c9fb917badc87c3591e55a939', '703362425232600.48927204706369', 1, 1)"

  end

  def self.down
  end

end
