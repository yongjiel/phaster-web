class AddSeqCountToBatches < ActiveRecord::Migration
  def change
    add_column :batches, :seq_count, :integer
  end
end
