# == Schema Information
# Schema version: 20090121183010
#
# Table name: plate_positions
#
#  id                 :integer(4)      not null, primary key
#  oligo_name         :string(100)     default(""), not null
#  plate_or_tube_name :string(30)
#  plate_or_tube_id   :integer(4)
#  well_number        :string(3)
#  plate_position     :integer(2)      default(0), not null
#  updated_at         :timestamp
#

class PlatePosition < ActiveRecord::Base
  belongs_to :plate_tube, :foreign_key => :plate_or_tube_id
  has_many :synth_oligos
  has_many :aliquot_to_pools
  has_many :pools, :through => :aliquot_to_pools
  
  WELL_LETTER = %w{A B C D E F G H}
  
  def well_coord
    well_alpha = WELL_LETTER[(plate_position - 1)/12]
    well_num   = (plate_position - 1) % 12 + 1 
    return well_alpha + well_num.to_s
  end
  
  def self.find_all_incl_oligos(condition_array=nil)
    self.find(:all, :include => :synth_oligos, :order => 'id', :conditions => condition_array)
  end
  
end
