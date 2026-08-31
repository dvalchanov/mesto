class ExpandCadastralPropertyFacts < ActiveRecord::Migration[8.1]
  def change
    change_table :cadastral_properties, bulk: true do |t|
      t.decimal :outline_area_sqm, precision: 14, scale: 2
      t.decimal :perimeter_m, precision: 14, scale: 2
      t.string :settlement_name
      t.string :address_floor
      t.string :block_number
      t.string :old_identifier
      t.string :ownership_type
      t.string :ownership_code
      t.string :purpose_code
      t.integer :objects_count
      t.integer :floors_count
      t.string :category_type
      t.string :territory_type
      t.string :territory_code
      t.string :permanent_use
      t.string :permanent_use_code
      t.string :quarter
      t.string :regulation_parcel
      t.string :place
      t.string :street_name
      t.string :street_number
      t.geometry :source_geometry, geographic: false, srid: 7801
      t.geometry :geometry, geographic: false, srid: 4326
    end

    add_index :cadastral_properties, :source_geometry, using: :gist
    add_index :cadastral_properties, :geometry, using: :gist
  end
end
