class Image < ActiveRecord::Base

  validates_presence_of :name, :image_ref
  validates_length_of :name, :maximum => 255
  validates_inclusion_of :os_type, :in => %w( linux windows ), :message => "OS Type must be either 'linux' or 'windows'.", :if => :os_type

  belongs_to :account

  attr_accessible :name, :image_ref, :os_type, :account_id, :is_active

  def self.sync(user)
    acct=user.account
    conn = acct.get_connection
    
    image_refs = []

    conn.all_images.each do |image|

      image_refs << (image.id.to_s)

      img = Image.find(:first, :conditions => ["account_id = ? and image_ref = ?", acct.id, image.id])
      if not img then
        os_type = image.name.index(/Windows/) ? "windows" : "linux"
        is_active = os_type.nil? ? false : true
        Image.create(:name => image.name, :image_ref => image.id, :account_id => acct.id, :os_type => os_type, :is_active => is_active)
      end


    end

    Image.find(:all, :conditions => ["account_id = ?", acct.id] ).each do |img|
      if not image_refs.include?(img.image_ref.to_s) then
        img.destroy
      end
    end
 
  end

end
