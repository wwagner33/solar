class RemoveColumnUseLocalNetwork < ActiveRecord::Migration[5.0]
  def up
  	remove_column :ip_reals, :use_local_network
  end
  def down
  	add_column :ip_reals, :use_local_network, :boolean
  end
end
