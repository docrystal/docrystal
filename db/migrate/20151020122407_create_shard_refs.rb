class CreateShardRefs < ActiveRecord::Migration
  def change
    create_table :shard_refs do |t|
      t.belongs_to :shard, index: true, foreign_key: true, null: false
      t.belongs_to :doc, index: true, null: false
      t.string :name, null: false

      t.timestamps null: false
    end

    add_foreign_key :shard_refs, :shard_docs, column: :doc_id
    add_index :shard_refs, %i(shard_id name), unique: true
  end
end
