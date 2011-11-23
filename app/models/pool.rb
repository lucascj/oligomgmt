# == Schema Information
# Schema version: 20090121183010
#
# Table name: pools
#
#  id                  :integer(4)      not null, primary key
#  pool_name           :string(35)      default(""), not null
#  tube_label          :string(15)      default(""), not null
#  pool_description    :string(80)
#  enzyme_code         :string(50)
#  source_conc_um      :decimal(8, 3)
#  pool_volume         :decimal(8, 3)
#  project_id          :integer(2)
#  storage_location_id :integer(2)
#  notes               :string(255)
#  updated_at          :timestamp
#

class Pool < InventoryDB
  has_many :aliquot_to_pools, :dependent => :destroy
  has_many :plate_positions, :through => :aliquot_to_pools
  belongs_to :storage_location
  
  serialize :from_pools, Array
  serialize :from_plates, Array
  
  accepts_nested_attributes_for :aliquot_to_pools, :allow_destroy => true
  
  validates_presence_of :tube_label
  
  def pool_type
    return tube_label[0,2]
  end
  
  def self.pool_types
    unique_pool_types = self.find(:all, :select => 'DISTINCT(LEFT(tube_label,2)) AS pool_type')
    return unique_pool_types.map{|pool| pool[:pool_type]}
  end
end
