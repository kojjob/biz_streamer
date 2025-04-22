class AddFieldsToProfiles < ActiveRecord::Migration[8.0]
  def change
    # Basic user information additions
    add_column :profiles, :headline, :string, limit: 100
    add_column :profiles, :birth_date, :date
    add_column :profiles, :gender, :string
    add_column :profiles, :preferred_language, :string, default: "en"
    
    # Contact and social information
    add_column :profiles, :social_links, :jsonb, default: {}
    add_column :profiles, :contact_email, :string
    add_column :profiles, :public_phone, :string
    
    # Professional information
    add_column :profiles, :expertise, :text, array: true, default: []
    add_column :profiles, :education, :jsonb, default: []
    add_column :profiles, :work_experience, :jsonb, default: []
    add_column :profiles, :certifications, :jsonb, default: []
    
    # Platform engagement metrics
    add_column :profiles, :streams_count, :integer, default: 0
    add_column :profiles, :total_sales_count, :integer, default: 0
    add_column :profiles, :total_commission_earned, :decimal, precision: 12, scale: 2, default: 0
    
    # Platform features
    add_column :profiles, :is_recommended, :boolean, default: false
    add_column :profiles, :trust_score, :integer, default: 0
    add_column :profiles, :ambassador_level, :string, default: "bronze"
    add_column :profiles, :badges, :jsonb, default: {}
    
    # Privacy settings
    add_column :profiles, :privacy_settings, :jsonb, default: {
      "show_email": false,
      "show_phone": false,
      "show_location": true,
      "show_birth_date": false,
      "show_sales_metrics": true
    }
    
    # Notification preferences
    add_column :profiles, :notification_preferences, :jsonb, default: {
      "email_marketing": true,
      "email_stream_notifications": true, 
      "email_order_updates": true,
      "push_messages": true,
      "push_stream_start": true
    }
    
    # Profile customization
    add_column :profiles, :theme_preference, :string, default: "light"
    add_column :profiles, :accent_color, :string
    add_column :profiles, :layout_preferences, :jsonb, default: {}
    
    # Scheduling and availability
    add_column :profiles, :availability_hours, :jsonb, default: {}
    add_column :profiles, :open_for_collaboration, :boolean, default: true
    add_column :profiles, :min_collaboration_budget, :decimal, precision: 10, scale: 2
    
    # Content preferences
    add_column :profiles, :content_interests, :jsonb, default: []
    add_column :profiles, :shopping_preferences, :jsonb, default: {}
    
    # Add indices for performance
    add_index :profiles, :ambassador_level
    add_index :profiles, :is_recommended
    add_index :profiles, :expertise, using: 'gin'
    add_index :profiles, :social_links, using: 'gin'
    add_index :profiles, :content_interests, using: 'gin'
    add_index :profiles, :privacy_settings, using: 'gin'
  end
end