class CreateTimeRegisters < ActiveRecord::Migration[8.0]
  def change
    create_table :time_registers do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :clock_in
      t.datetime :clock_out

      t.timestamps
    end
  end
end
