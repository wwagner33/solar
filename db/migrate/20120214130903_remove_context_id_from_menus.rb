class RemoveContextIdFromMenus < ActiveRecord::Migration[5.0]
  def self.up
    remove_column :menus, :context_id
  end

  def self.down
    add_column :menus, :context_id, :t.integer
  end
end
