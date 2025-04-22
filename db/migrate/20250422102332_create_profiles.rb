class CreateProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :username
      t.string :display_name
      t.text :bio
      t.string :profile_image

      t.timestamps
    end
  end
end
