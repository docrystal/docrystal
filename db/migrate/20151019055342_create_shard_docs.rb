class CreateShardDocs < ActiveRecord::Migration
  def change
    create_table :shard_docs do |t|
      t.belongs_to :shard, index: true, foreign_key: true, null: false
      t.string :sha, null: false
      t.string :error, null: true
      t.text :error_description, null: true
      t.datetime :generated_at, null: true

      t.timestamps null: false
    end

    add_index :shard_docs, %i(shard_id sha), unique: true
  end
end
