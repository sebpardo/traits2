
puts "********Seeding Data Start************"

users = User.create!(first_name: "Dr", last_name: "Admin", email: "admin@traits.org", password: "foobar", password_confirmation: "foobar", contributor: true, editor: true, admin: true, activated: true, activated_at: Time.zone.now)

traitclasses = Traitclass.create!([
  { :class_name => 'Contextual', :user_id => 1, :contextual => true }, 
  { :class_name => 'Ecological', :user_id => 1 }, 
  { :class_name => 'Organismal', :user_id => 1 }
  ])

traits = Trait.create!([
  {user_id: 1, trait_name: "Growth rate", trait_description: "", traitclass_id: 3, standard_id: 16, log_data: true, approved: false, released: false, hide: false},
  {user_id: 1, trait_name: "Growth form", trait_description: "The morphology of the organism.", traitclass_id: 3, standard_id: 1, log_data: false, approved: false, released: false, hide: false},
  {user_id: 1, trait_name: "Depth", trait_description: "The depth at which the organism was observed.", traitclass_id: 1, standard_id: 4, log_data: false, approved: false, released: false, hide: false},
  {user_id: 1, trait_name: "Reproductive mode", trait_description: "Mode of reproduction.", traitclass_id: 3, standard_id: 1, log_data: false, approved: false, released: false, hide: false},
  {user_id: 1, trait_name: "Age at maturity", trait_description: "Average age at which maturity is reached.", traitclass_id: 2, standard_id: 9, log_data: false, approved: false, released: false, hide: false},
  {user_id: 1, trait_name: "Size at maturity", trait_description: "Average size in centimeters at which maturity is reached.", traitclass_id: 2, standard_id: 9, log_data: false, approved: false, released: false, hide: false},
  {user_id: 1, trait_name: "Sex", trait_description: "Sex for which the value was obtained.", traitclass_id: 3, standard_id: 1, log_data: false, approved: false, released: false, hide: false},
  {user_id: 1, trait_name: "Size at birth", trait_description: "Average size in centimeters at birth.", traitclass_id: 2, standard_id: 9, log_data: false, approved: false, released: false, hide: false}
  ])
 
standards = Standard.create!([
  { :standard_name => 'Category', :standard_unit => 'cat', :standard_class => 'Nominal class', :user_id => 1 }, 
  { :standard_name => 'Name', :standard_unit => 'text', :standard_class => 'Nominal class', :user_id => 1 }, 
  { :standard_name => 'Degrees Celsius', :standard_unit => 'ºC', :standard_class => 'Base unit', :user_id => 1 }, 
  { :standard_name => 'Meter', :standard_unit => 'm', :standard_class => 'Base unit', :user_id => 1 }, 
  { :standard_name => 'Count', :standard_unit => 'units', :standard_class => 'Base unit', :user_id => 1 }, 
  { :standard_name => 'Degrees', :standard_unit => 'deg', :standard_class => 'Base unit', :user_id => 1 }, 
  { :standard_name => 'Millimeter', :standard_unit => 'mm', :standard_class => 'Base unit', :user_id => 1 }, 
  { :standard_name => 'Density', :standard_unit => 'm2/m2', :standard_class => 'Index', :user_id => 1 }, 
  { :standard_name => 'Year', :standard_unit => 'yr', :standard_class => 'Datetime', :user_id => 1 }, 
  { :standard_name => 'Meter square', :standard_unit => 'm2', :standard_class => 'Simple derived unit', :user_id => 1 }, 
  { :standard_name => 'Density', :standard_unit => 'kg/m2', :standard_class => 'Complex derived unit', :user_id => 1 }, 
  { :standard_name => 'Density', :standard_unit => 'kg/m3', :standard_class => 'Complex derived unit', :user_id => 1 }, 
  { :standard_name => 'Density', :standard_unit => 'kg/kg', :standard_class => 'Index', :user_id => 1 }, 
  { :standard_name => 'Kilogram', :standard_unit => 'kg', :standard_class => 'Base unit', :user_id => 1 }, 
  { :standard_name => 'Text', :standard_unit => 'text', :standard_class => 'Nominal class', :user_id => 1 } ,
  { :standard_name => 'Centimeter', :standard_unit => 'cm', :standard_class => 'Base unit', :user_id => 1 }, 
  { :standard_name => 'Year-1', :standard_unit => 'yr-1', :standard_class => 'Complex derived unit', :user_id => 1 } 
  ])

Valuetype.create!([
  {user_id: 1, value_type_name: "Raw value", value_type_description: "Value as measured by observer.", has_precision: false},
  {user_id: 1, value_type_name: "Model output", value_type_description: "Value estimated from a model.", has_precision: false}
])

Traitvalue.create!([
  {value_name: "male", trait_id: 7, value_description: "male"},
  {value_name: "female", trait_id: 7, value_description: "female"},
  {value_name: "combined", trait_id: 7, value_description: "combined"},
  {value_name: "0", trait_id: 8, value_description: "supressed"},
  {value_name: "1", trait_id: 8, value_description: "intermediate"},
  {value_name: "2", trait_id: 8, value_description: "codominant (crown partly exposed)"},
  {value_name: "3", trait_id: 8, value_description: "dominant (crown fully exposed)"},
  {value_name: "Blank", trait_id: 1, value_description: "plantations / glasshouse / common garden"},
  {value_name: "Sav", trait_id: 1, value_description: "Savannah"},
  {value_name: "TropRF", trait_id: 1, value_description: "Tropical rainforest"},
  {value_name: "TempRF", trait_id: 1, value_description: "Temperate rainforest"},
  {value_name: "TropSF", trait_id: 1, value_description: "Tropical seasonal forest"},
  {value_name: "TempF", trait_id: 1, value_description: "Temperate forest"},
  {value_name: "BorF", trait_id: 1, value_description: "Boreal forest"},
  {value_name: "Wo", trait_id: 1, value_description: "Woodland"},
  {value_name: "Gr", trait_id: 1, value_description: "Grassland"},
  {value_name: "Sh", trait_id: 1, value_description: "Shrubland"},
  {value_name: "De", trait_id: 1, value_description: "Desert"},
  {value_name: "EA", trait_id: 6, value_description: "evergreen angiosperm"},
  {value_name: "DA", trait_id: 6, value_description: "deciduous angiosperm"},
  {value_name: "EG", trait_id: 6, value_description: "evergreen gymnosperm"},
  {value_name: "DG", trait_id: 6, value_description: "deciduous gymnosperm"},
  {value_name: "egg", trait_id: 4, value_description: "egg laying"},
  {value_name: "leici", trait_id: 4, value_description: "leicithotrophic viviparity"},
  {value_name: "matri", trait_id: 4, value_description: "maitithrophic viviparity"},
  {value_name: "matrioo", trait_id: 4, value_description: "maitithrophic viviparity with oophagy"},
  {value_name: "matriadel", trait_id: 4, value_description: "maitithrophic viviparity with adelphophagy"},
  {value_name: "histo", trait_id: 4, value_description: "histotrophic viviparity"},
  {value_name: "placental", trait_id: 4, value_description: "placental viviparity"}
])
