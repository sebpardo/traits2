Location.create!([
  {user_id: 1, location_name: "Global Estimate", latitude: "0.0", longitude: "0.0", location_description: nil, approved: nil},
])
Methodology.create!([
  {user_id: 1, methodology_name: "Depth gage", methodology_description: "", approved: false},
  {user_id: 1, methodology_name: "X-radiography", methodology_description: "", approved: false}
])
Traitclass.create!([
  {user_id: 1, class_name: "Contextual", class_description: nil, contextual: true},
  {user_id: 1, class_name: "Ecological", class_description: nil, contextual: nil},
  {user_id: 1, class_name: "Organismal", class_description: nil, contextual: nil}
])
Traitvalue.create!([
  {value_name: "Digitate", trait_id: 2, value_description: ""},
  {value_name: "Tabular", trait_id: 2, value_description: ""},
  {value_name: "Massive", trait_id: 2, value_description: ""}
])

User.create!(first_name: "Dr", last_name: "Admin", email: "admin@traits.org", password: "foobar", password_confirmation: "foobar", contributor: true, editor: true, admin: true, activated: true, activated_at: Time.zone.now)

Valuetype.create!([
  {user_id: 1, value_type_name: "Raw value", value_type_description: "Value as measured by observer.", has_precision: false},
  {user_id: 1, value_type_name: "Mean", value_type_description: "The mean of multiple raw values.", has_precision: true}
])
