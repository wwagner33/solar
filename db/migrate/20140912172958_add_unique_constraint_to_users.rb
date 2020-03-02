class AddUniqueConstraintToUsers < ActiveRecord::Migration[5.0]
  def change
    add_index :users, [:cpf], unique: true
  end
end
