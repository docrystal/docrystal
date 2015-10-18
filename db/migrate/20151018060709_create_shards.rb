class CreateShards < ActiveRecord::Migration
  def change
    create_table :shards do |t|
      t.string :hosting, null: false, limit: 20
      t.string :owner, null: false
      t.string :name, null: false

      t.timestamps null: false
    end

    add_index :shards, %i(hosting owner name), name: 'idx_shards', unique: true
  end
end
