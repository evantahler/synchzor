class CreateDbFolders < ActiveRecord::Migration
  def self.up
    create_table :synch_folders do |t|
      t.string :local_folder
      t.string :remote_folder
      t.datetime :last_sync_timestamp
      t.string :username
      t.string :password
      t.string :host
      t.integer :port
      t.string :cert
      t.timestamps
    end
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
