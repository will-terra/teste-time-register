class CreateReports < ActiveRecord::Migration[8.0]
  def change
    create_table :reports do |t|
      t.uuid :process_id, null: false
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: 'queued'
      t.integer :progress, null: false, default: 0
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.string :file_path
      t.text :error_message

      t.timestamps
    end
    add_index :reports, :process_id, unique: true
    add_index :reports, :status
    add_index :reports, [:user_id, :created_at]
  end
end
